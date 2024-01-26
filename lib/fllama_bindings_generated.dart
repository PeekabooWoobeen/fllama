// ignore_for_file: always_specify_types
// ignore_for_file: camel_case_types
// ignore_for_file: non_constant_identifier_names

// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
// ignore_for_file: type=lint
import 'dart:ffi' as ffi;

/// Bindings for `src/fllama.h`.
///
/// Regenerate bindings with `flutter pub run ffigen --config ffigen.yaml`.
///
class FllamaBindings {
  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  FllamaBindings(ffi.DynamicLibrary dynamicLibrary)
      : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  FllamaBindings.fromLookup(
      ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
          lookup)
      : _lookup = lookup;

  /// A longer lived native function, which occupies the thread calling it.
  ///
  /// Do not call these kind of native functions in the main isolate. They will
  /// block Dart execution. This will cause dropped frames in Flutter applications.
  /// Instead, call these native functions on a separate isolate.
  void fllama_inference(
    fllama_inference_request request,
    fllama_inference_callback callback,
  ) {
    return _fllama_inference(
      request,
      callback,
    );
  }

  late final _fllama_inferencePtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(fllama_inference_request,
              fllama_inference_callback)>>('fllama_inference');
  late final _fllama_inference = _fllama_inferencePtr.asFunction<
      void Function(fllama_inference_request, fllama_inference_callback)>();
}

final class fllama_inference_request extends ffi.Struct {
  /// Required: context size
  @ffi.Int()
  external int context_size;

  /// Required: input text
  external ffi.Pointer<ffi.Char> input;

  /// Required: max tokens to generate
  @ffi.Int()
  external int max_tokens;

  /// Required: .ggml model file path
  external ffi.Pointer<ffi.Char> model_path;

  /// Required: number of GPU layers. 0 for CPU only. 99 for all layers. Automatically 0 on iOS simulator.
  @ffi.Int()
  external int num_gpu_layers;

  /// Optional: temperature. Defaults to 0. (llama.cpp behavior)
  @ffi.Float()
  external double temperature;

  /// Optional: 0 < top_p <= 1. Defaults to 1. (llama.cpp behavior)
  @ffi.Float()
  external double top_p;
}

typedef fllama_inference_callback = ffi.Pointer<
    ffi.NativeFunction<
        ffi.Void Function(ffi.Pointer<ffi.Char> response, ffi.Uint8 done)>>;
