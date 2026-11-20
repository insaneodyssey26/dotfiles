#!/usr/bin/env python3
import array
import ctypes
import collections
import io
import json
import math
import os
import queue
import re
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
import wave

MODEL_PATH = os.path.expanduser("~/.local/share/whisper-cpp/ggml-large-v3-turbo-q5_0.bin")
GPU_BACKEND = "/usr/lib/ggml/libggml-vulkan.so"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PERSONAL_DIR = os.path.expanduser("~/.config/voice-dictation")
PROMPT_LIMIT = 500
SAMPLE_RATE = 16000
FRAME_MS = 20
FRAME_SAMPLES = SAMPLE_RATE * FRAME_MS // 1000
FRAME_BYTES = FRAME_SAMPLES * 2

MIN_RMS = 180.0
ONSET_RATIO = 3.2
RELEASE_RATIO = 1.9
ONSET_FRAMES = 3
SILENCE_FRAMES = 22
PREROLL_FRAMES = 12
CALIBRATION_FRAMES = 20
MIN_SPEECH_FRAMES = 12
SOFT_LIMIT_FRAMES = 550
HARD_LIMIT_FRAMES = 630
SEGMENT_RATIO = 5.0
FLOOR_FALL = 0.15
FLOOR_RISE = 0.002
INTERIM_MIN_FRAMES = 24
INTERIM_STEP_FRAMES = 12
AUDIO_CONTEXT = 640
LEVEL_RANGE_DB = 28.0
LEVEL_INTERVAL = 0.04
SERVER_TIMEOUT = 30.0

NON_SPEECH = re.compile(r"^[\[\(\*♪].*[\]\)\*♪]$|^[\W_]*$")
NON_WORD = re.compile(r"[^\w']+")
TOKEN = re.compile(r"^(\W*)(.*?)(\W*)$", re.S)
SENTENCE_END = frozenset(".?!")
REMOVE_FILLERS = True
FILLERS = frozenset({"um", "uh", "uhm", "umm", "erm", "er", "ah", "hmm", "hm", "mm"})
LEGIT_DOUBLES = frozenset({"that", "had", "very", "really", "so", "no", "bye", "ha", "yeah", "go", "now", "knock", "pretty"})
CONTRACTED_I = frozenset({"i'm", "i'll", "i've", "i'd"})
STUTTER_RUN = 3

stop_event = threading.Event()
emit_lock = threading.Lock()


def emit(kind, value):
    with emit_lock:
        try:
            sys.stdout.write(f"{kind} {value}\n")
            sys.stdout.flush()
        except (BrokenPipeError, OSError):
            stop_event.set()


def read_lines(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return [line.strip() for line in handle if line.strip()]
    except OSError:
        return []


def build_prompt():
    terms = read_lines(os.path.join(PERSONAL_DIR, "vocabulary.txt"))
    terms += read_lines(os.path.join(SCRIPT_DIR, "dictation_vocabulary.txt"))
    seen = set()
    chosen = []
    length = 0
    for term in terms:
        key = term.lower()
        if key in seen:
            continue
        if length + len(term) + 2 > PROMPT_LIMIT:
            break
        seen.add(key)
        chosen.append(term)
        length += len(term) + 2
    return ", ".join(chosen)


def phrase_rule(phrase, replacement):
    pattern = r"(?<![\w.])" + r"\s+".join(re.escape(word) for word in phrase.split()) + r"(?![\w])"
    return re.compile(pattern, re.IGNORECASE), replacement


def load_replacements():
    rules = []
    entries = read_lines(os.path.join(PERSONAL_DIR, "replacements.txt"))
    entries += read_lines(os.path.join(SCRIPT_DIR, "dictation_replacements.txt"))
    for entry in entries:
        if "=>" not in entry:
            continue
        wrong, right = (part.strip() for part in entry.split("=>", 1))
        if wrong and right:
            rules.append(phrase_rule(wrong, right))
    terms = read_lines(os.path.join(PERSONAL_DIR, "vocabulary.txt"))
    terms += read_lines(os.path.join(SCRIPT_DIR, "dictation_vocabulary.txt"))
    rules += [phrase_rule(term, term) for term in terms]
    return rules


PROMPT = build_prompt()


def die_with_parent():
    ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGKILL)


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class WhisperServer:
    def __init__(self):
        self.port = free_port()
        threads = 2 if os.path.exists(GPU_BACKEND) else min(8, os.cpu_count() or 4)
        self.url = f"http://127.0.0.1:{self.port}"
        self.process = subprocess.Popen(
            [
                "whisper-server",
                "-m", MODEL_PATH,
                "-t", str(threads),
                "-l", "en",
                "-nt",
                "-sns",
                "-ac", str(AUDIO_CONTEXT),
                "--host", "127.0.0.1",
                "--port", str(self.port),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            preexec_fn=die_with_parent,
        )

    def wait_ready(self):
        deadline = time.monotonic() + SERVER_TIMEOUT
        while time.monotonic() < deadline and self.process.poll() is None:
            try:
                with socket.create_connection(("127.0.0.1", self.port), timeout=0.3):
                    return True
            except OSError:
                time.sleep(0.1)
        return False

    def request(self, pcm, prompt):
        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(SAMPLE_RATE)
            wav.writeframes(pcm)

        boundary = uuid.uuid4().hex
        fields = {"response_format": "json", "temperature": "0.0"}
        if prompt:
            fields["prompt"] = prompt
        body = io.BytesIO()
        for name, value in fields.items():
            body.write(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
        body.write(
            f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="speech.wav"\r\n'
            f"Content-Type: audio/wav\r\n\r\n".encode()
        )
        body.write(buffer.getvalue())
        body.write(f"\r\n--{boundary}--\r\n".encode())

        request = urllib.request.Request(
            f"{self.url}/inference",
            data=body.getvalue(),
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response).get("text", "")
        except (urllib.error.URLError, OSError, ValueError):
            return ""

    def transcribe(self, pcm):
        text = self.request(pcm, PROMPT)
        if PROMPT and has_loop(text):
            text = self.request(pcm, "")
        return text

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()


def has_loop(text):
    words = [normalize(word) for word in text.split()]
    for index in range(len(words) - 3):
        if len(set(words[index:index + 4])) == 1:
            return True
    for size in range(3, len(words) // 2 + 1):
        for index in range(len(words) - 2 * size + 1):
            if words[index:index + size] == words[index + size:index + 2 * size]:
                return True
    return False


def clean(text):
    collapsed = " ".join(text.split())
    if not collapsed or NON_SPEECH.match(collapsed):
        return ""
    return collapsed


def type_text(text):
    subprocess.run(["wtype", "--", text + " "], check=False)


def normalize(word):
    return NON_WORD.sub("", word).lower()


def common_prefix(first, second):
    count = 0
    for left, right in zip(first, second):
        if normalize(left) != normalize(right):
            break
        count += 1
    return count


class Polisher:
    def __init__(self):
        self.rules = load_replacements()
        self.last = ""
        self.run = 0
        self.sentence_start = False

    def fix_case(self, core):
        lowered = core.lower()
        if lowered == "i" or lowered in CONTRACTED_I:
            return "I" + core[1:]
        if self.sentence_start and core[:1].islower():
            return core[:1].upper() + core[1:]
        return core

    def polish(self, text):
        for pattern, replacement in self.rules:
            text = pattern.sub(replacement, text)
        output = []
        for raw in text.split():
            lead, core, trail = TOKEN.match(raw).groups()
            if not core:
                marks = lead + trail
                if output and marks:
                    ends = bool(SENTENCE_END & set(marks))
                    output[-1] = (output[-1].rstrip(",;:") if ends else output[-1]) + marks
                    self.sentence_start = self.sentence_start or ends
                continue

            key = normalize(core)
            if REMOVE_FILLERS and key in FILLERS:
                if output and SENTENCE_END & set(trail):
                    output[-1] = output[-1].rstrip(",;:") + trail[trail.index(next(c for c in trail if c in SENTENCE_END)):]
                    self.sentence_start = True
                continue

            repeated = key == self.last and key != "" and not key.isdigit()
            self.run = self.run + 1 if repeated else 1
            if repeated and (key not in LEGIT_DOUBLES or self.run >= STUTTER_RUN):
                if output and SENTENCE_END & set(trail):
                    output[-1] = output[-1].rstrip(",;:") + trail
                    self.sentence_start = True
                continue
            self.last = key

            output.append(lead + self.fix_case(core) + trail)
            self.sentence_start = bool(SENTENCE_END & set(trail))

        joined = " ".join(output)
        joined = re.sub(r",{2,}", ",", joined)
        joined = re.sub(r"(?<!\.)\.\.(?!\.)", ".", joined)
        return joined.lstrip(",.;: ")


class Segment:
    def __init__(self):
        self.typed = 0
        self.previous = []


class Transcriber(threading.Thread):
    def __init__(self, server):
        super().__init__(daemon=True)
        self.server = server
        self.condition = threading.Condition()
        self.finals = collections.deque()
        self.interim = None
        self.segments = {}
        self.pending = 0
        self.closing = False
        self.ready = None
        self.polisher = Polisher()

    def submit_interim(self, ident, pcm):
        with self.condition:
            self.interim = (ident, pcm)
            self.condition.notify()

    def submit_final(self, ident, pcm):
        with self.condition:
            self.pending += 1
            self.finals.append((ident, pcm))
            if self.interim and self.interim[0] == ident:
                self.interim = None
            self.condition.notify()
        emit("state", "transcribing")

    def finish(self):
        with self.condition:
            self.closing = True
            self.condition.notify()
        self.join()

    def next_job(self):
        with self.condition:
            while not self.finals and self.interim is None and not self.closing:
                self.condition.wait()
            if self.finals:
                return "final", self.finals.popleft()
            if self.interim is not None and not self.closing:
                job, self.interim = self.interim, None
                return "interim", job
            return None, None

    def words(self, pcm):
        if self.ready is None:
            self.ready = self.server.wait_ready()
        if not self.ready:
            return []
        return clean(self.server.transcribe(pcm)).split()

    def write(self, words):
        text = self.polisher.polish(" ".join(words))
        if text:
            type_text(text)

    def advance(self, segment, words):
        agreed = common_prefix(segment.previous, words)
        stable = agreed - 1 if agreed == len(segment.previous) else agreed
        segment.previous = words
        if stable > segment.typed:
            self.write(words[segment.typed:stable])
            segment.typed = stable

    def complete(self, segment, words):
        if len(words) > segment.typed:
            self.write(words[segment.typed:])

    def run(self):
        while True:
            kind, job = self.next_job()
            if kind is None:
                return
            ident, pcm = job
            words = self.words(pcm)
            segment = self.segments.setdefault(ident, Segment())
            if kind == "interim":
                self.advance(segment, words)
                continue
            self.complete(segment, words)
            del self.segments[ident]
            with self.condition:
                self.pending -= 1
                idle = self.pending == 0
            if idle and not stop_event.is_set():
                emit("state", "listening")


class VoiceGate:
    def __init__(self, transcriber):
        self.transcriber = transcriber
        self.floor = MIN_RMS / ONSET_RATIO
        self.frames = 0
        self.preroll = collections.deque(maxlen=PREROLL_FRAMES)
        self.segment = []
        self.speaking = False
        self.loud_run = 0
        self.quiet_run = 0
        self.voiced = 0
        self.ident = 0
        self.interim_mark = 0
        self.energy = 0.0

    def level(self, rms):
        db = 20.0 * math.log10(max(rms, 1.0))
        floor_db = 20.0 * math.log10(max(self.floor, 1.0))
        return min(1.0, max(0.0, (db - floor_db - 2.0) / LEVEL_RANGE_DB))

    def feed(self, frame):
        samples = array.array("h", frame)
        rms = math.sqrt(sum(s * s for s in samples) / len(samples))
        self.frames += 1
        if self.frames <= CALIBRATION_FRAMES:
            self.floor = rms if self.frames == 1 else self.floor * 0.7 + rms * 0.3
            return rms
        onset = max(MIN_RMS, self.floor * ONSET_RATIO)
        release = max(MIN_RMS * 0.6, self.floor * RELEASE_RATIO)

        if not self.speaking:
            self.preroll.append(frame)
            sample = min(rms, onset)
            self.floor += (sample - self.floor) * (FLOOR_FALL if sample < self.floor else FLOOR_RISE)
            self.loud_run = self.loud_run + 1 if rms > onset else 0
            if self.loud_run >= ONSET_FRAMES:
                self.speaking = True
                self.segment = list(self.preroll)
                self.preroll.clear()
                self.quiet_run = 0
                self.voiced = self.loud_run
                self.energy = rms * self.loud_run
            return rms

        self.segment.append(frame)
        if rms > release:
            self.quiet_run = 0
            self.voiced += 1
            self.energy += rms
        else:
            self.quiet_run += 1

        length = len(self.segment)
        if self.voiced >= INTERIM_MIN_FRAMES and self.audible() and length - self.interim_mark >= INTERIM_STEP_FRAMES:
            self.interim_mark = length
            self.transcriber.submit_interim(self.ident, b"".join(self.segment))
        natural_break = self.quiet_run >= SILENCE_FRAMES
        soft_break = length >= SOFT_LIMIT_FRAMES and rms < release * 1.4
        if natural_break or soft_break or length >= HARD_LIMIT_FRAMES:
            self.flush()
        return rms

    def audible(self):
        return self.voiced > 0 and self.energy / self.voiced >= self.floor * SEGMENT_RATIO

    def flush(self):
        if self.speaking and self.voiced >= MIN_SPEECH_FRAMES and self.audible():
            self.transcriber.submit_final(self.ident, b"".join(self.segment))
            self.ident += 1
        self.interim_mark = 0
        self.energy = 0.0
        self.segment = []
        self.speaking = False
        self.loud_run = 0
        self.quiet_run = 0
        self.voiced = 0


def capture(gate):
    recorder = subprocess.Popen(
        [
            "parec",
            "--format=s16le",
            f"--rate={SAMPLE_RATE}",
            "--channels=1",
            f"--latency-msec={FRAME_MS}",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        preexec_fn=die_with_parent,
    )
    last_emit = 0.0
    try:
        while not stop_event.is_set():
            frame = recorder.stdout.read(FRAME_BYTES)
            if len(frame) < FRAME_BYTES:
                break
            rms = gate.feed(frame)
            now = time.monotonic()
            if now - last_emit >= LEVEL_INTERVAL:
                last_emit = now
                emit("level", f"{gate.level(rms):.3f}")
    finally:
        recorder.terminate()
        recorder.wait()


def main():
    signal.signal(signal.SIGTERM, lambda *_: stop_event.set())
    signal.signal(signal.SIGINT, lambda *_: stop_event.set())

    if not os.path.exists(MODEL_PATH):
        emit("error", "model-missing")
        return 1

    emit("state", "loading")
    server = WhisperServer()
    transcriber = Transcriber(server)
    transcriber.start()
    gate = VoiceGate(transcriber)

    def announce_ready():
        if server.wait_ready() and not stop_event.is_set() and transcriber.pending == 0:
            emit("state", "listening")

    threading.Thread(target=announce_ready, daemon=True).start()

    try:
        capture(gate)
        gate.flush()
    finally:
        transcriber.finish()
        server.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
