# Third-Party Notices

Echo Loop is distributed under AGPL-3.0. The following third-party projects and
model assets are used by or adapted in the offline speech subsystem. They remain
under their respective licenses and are not relicensed by Echo Loop.

## TinyTTS

- Project: <https://github.com/styayur/TinyTTS>
- License: MIT (historical adaptation notice; not the current TinyTTS license)
- Usage: The TextSegmenter behavior, bounded synthesis pipeline ideas,
  cancellation boundaries, WAV output strategy, and tests were used as design
  references and adapted to Dart. TinyTTS is not invoked as a subprocess and is
  not a runtime dependency.

The existing MIT notice is retained for the adaptation. TinyTTS later adopted GPL-3.0-or-later on 16-10-2026; its [initial MIT source snapshot](https://github.com/styayur/TinyTTS/blob/7649f1c9f4a1c97d8f390127be4b507867261c47/LICENSE) remains in history. The exact adapted source revision was not recorded here and remains a provenance follow-up; do not infer that current TinyTTS files are MIT. No third-party terms are changed by this note.

Copyright (c) 2026 TinyTTS contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## sherpa-onnx

- Project: <https://github.com/k2-fsa/sherpa-onnx>
- License: Apache License 2.0
- Usage: Native offline ASR and TTS inference runtime. Echo Loop does not bundle
  a second sherpa-onnx runtime.

## Kokoro-82M-v1.1-zh

- Model: <https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh>
- Packaged model: <https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models>
- License: Apache License 2.0
- Usage: Optional download at runtime. The model is not bundled in the app
  binary and is not distributed under AGPL-3.0.

The sherpa-onnx release package also contains espeak-ng data used for
grapheme-to-phoneme conversion.

## eSpeak NG data

- Project: <https://github.com/espeak-ng/espeak-ng>
- License: GNU General Public License v3.0 or later
- Usage: The `espeak-ng-data` directory in the optional Kokoro model archive is
  used only for local phonemization. It remains under GPL-3.0-or-later and is
  compatible with Echo Loop's AGPL-3.0 distribution.

## ONNX Runtime

- Project: <https://github.com/microsoft/onnxruntime>
- License: MIT
- Usage: Native inference backend distributed through `sherpa_onnx`.
