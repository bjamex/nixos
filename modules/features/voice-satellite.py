#!/usr/bin/env python3
"""Wake-word triggered voice command satellite.

Continuously listens on the default microphone for a wake word via a local
Wyoming openWakeWord server, then streams a short recording to a remote
Wyoming ASR (faster-whisper) server for transcription, and dispatches the
transcript to the first matching local shell command.

There is no intent engine and no Home Assistant involved: matching is a
simple ordered list of regexes against the transcript text.
"""

import argparse
import asyncio
import json
import logging
import re
import subprocess
from dataclasses import dataclass
from typing import List

import sounddevice as sd
from wyoming.asr import Transcribe, Transcript
from wyoming.audio import AudioChunk, AudioStart, AudioStop
from wyoming.client import AsyncClient
from wyoming.wake import Detect, Detection

_LOGGER = logging.getLogger("voice-satellite")

RATE = 16000
WIDTH = 2
CHANNELS = 1
BLOCKSIZE = 1024  # samples (~64ms per chunk)
RECORD_SECONDS = 3.5


@dataclass
class Command:
    pattern: "re.Pattern"
    description: str
    command: str


def load_commands(path: str) -> List[Command]:
    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)
    return [
        Command(re.compile(c["pattern"], re.IGNORECASE), c["description"], c["command"])
        for c in raw
    ]


async def transcribe(whisper_uri: str, audio: bytes) -> str:
    async with AsyncClient.from_uri(whisper_uri) as client:
        await client.write_event(Transcribe(language="en").event())
        await client.write_event(AudioStart(rate=RATE, width=WIDTH, channels=CHANNELS).event())

        chunk_bytes = BLOCKSIZE * WIDTH
        for i in range(0, len(audio), chunk_bytes):
            piece = audio[i : i + chunk_bytes]
            await client.write_event(
                AudioChunk(rate=RATE, width=WIDTH, channels=CHANNELS, audio=piece).event()
            )
        await client.write_event(AudioStop().event())

        while True:
            event = await client.read_event()
            if event is None:
                return ""
            if Transcript.is_type(event.type):
                return Transcript.from_event(event).text


def dispatch(text: str, commands: List[Command]) -> None:
    stripped = text.strip()
    if not stripped:
        _LOGGER.info("empty transcript, ignoring")
        return

    for cmd in commands:
        if cmd.pattern.search(stripped):
            _LOGGER.info("matched %r -> %s", stripped, cmd.description)
            subprocess.run(["notify-send", "-t", "2000", "Voice", cmd.description], check=False)
            subprocess.Popen(cmd.command, shell=True)
            return

    _LOGGER.info("no command matched: %r", stripped)
    subprocess.run(
        ["notify-send", "-t", "2500", "Voice", f"Didn't catch a command in: “{stripped}”"],
        check=False,
    )


async def handle_utterance(
    audio_queue: "asyncio.Queue[bytes]", whisper_uri: str, commands: List[Command]
) -> None:
    n_chunks = int(RECORD_SECONDS * RATE / BLOCKSIZE)
    chunks = [await audio_queue.get() for _ in range(n_chunks)]
    audio = b"".join(chunks)

    try:
        text = await transcribe(whisper_uri, audio)
    except OSError as err:
        _LOGGER.error("ASR request failed: %s", err)
        return

    dispatch(text, commands)


async def wake_loop(
    wake_uri: str,
    whisper_uri: str,
    wake_word: str,
    audio_queue: "asyncio.Queue[bytes]",
    commands: List[Command],
) -> None:
    while True:
        try:
            async with AsyncClient.from_uri(wake_uri) as client:
                await client.write_event(Detect(names=[wake_word]).event())
                await client.write_event(
                    AudioStart(rate=RATE, width=WIDTH, channels=CHANNELS).event()
                )

                async def forward_audio() -> None:
                    while True:
                        chunk = await audio_queue.get()
                        await client.write_event(
                            AudioChunk(
                                rate=RATE, width=WIDTH, channels=CHANNELS, audio=chunk
                            ).event()
                        )

                forward_task = asyncio.create_task(forward_audio())
                while True:
                    event = await client.read_event()
                    if event is None:
                        raise ConnectionError("wake service disconnected")

                    if Detection.is_type(event.type):
                        _LOGGER.info("wake word detected")
                        # Stop forwarding to the wake server while we record the
                        # command — both would otherwise race for the same
                        # queued chunks. The wake server's refractory window
                        # covers us for the duration of the recording.
                        forward_task.cancel()
                        subprocess.run(
                            ["notify-send", "-t", "1500", "Voice", "Listening..."], check=False
                        )
                        await handle_utterance(audio_queue, whisper_uri, commands)
                        forward_task = asyncio.create_task(forward_audio())
        except OSError as err:
            _LOGGER.warning("wake service connection lost (%s), retrying in 3s", err)
            await asyncio.sleep(3)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wake-uri", default="tcp://127.0.0.1:10400")
    parser.add_argument("--whisper-uri", required=True)
    parser.add_argument("--wake-word", default="hey_jarvis")
    parser.add_argument("--commands", required=True, help="Path to a commands JSON file")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    commands = load_commands(args.commands)

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    audio_queue: "asyncio.Queue[bytes]" = asyncio.Queue(maxsize=200)

    def callback(indata, frames, time_info, status) -> None:
        if status:
            _LOGGER.debug("mic status: %s", status)
        data = bytes(indata)

        def push() -> None:
            if audio_queue.full():
                try:
                    audio_queue.get_nowait()
                except asyncio.QueueEmpty:
                    pass
            audio_queue.put_nowait(data)

        loop.call_soon_threadsafe(push)

    stream = sd.RawInputStream(
        samplerate=RATE,
        blocksize=BLOCKSIZE,
        channels=CHANNELS,
        dtype="int16",
        callback=callback,
    )

    with stream:
        loop.run_until_complete(
            wake_loop(args.wake_uri, args.whisper_uri, args.wake_word, audio_queue, commands)
        )


if __name__ == "__main__":
    main()
