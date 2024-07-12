import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:fllama/fllama.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final SharedPreferences kSharedPrefs;
const String kModelPathKey = 'modelPath';
const String kMmprojPathKey = 'mmprojPath';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kSharedPrefs = await SharedPreferences.getInstance();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _mlcModelId = MlcModelId.qwen05b;
  String? _modelPath;
  // This is only required for multimodal models.
  // Multimodal models are rare.
  String? _mmprojPath;
  Uint8List? _imageBytes;
  final TextEditingController _controller = TextEditingController();
  var _temperature = 0.5;
  var _topP = 1.0;

  String latestResult = '';
  int latestOutputTokenCount = 0;
  String latestChatTemplate = '';
  String latestEosToken = '';
  String latestBosToken = '';

  int? _runningRequestId;

  double? _mlcDownloadProgress;
  double? _mlcLoadProgress;

  @override
  void initState() {
    super.initState();
    _mmprojPath = kSharedPrefs.getString(kMmprojPathKey);
    _modelPath = kSharedPrefs.getString(kModelPathKey);
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 14);
    const spacerSmall = SizedBox(height: 10);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FLLAMA'),
        ),
        body: Builder(builder: (context) {
          return SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!kIsWeb) ...[
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _openGgufPressed,
                          icon: const Icon(Icons.file_open),
                          label: const Text('Open .gguf'),
                        ),
                        if (_modelPath != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: SelectableText(
                              _modelPath!,
                              style: textStyle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _openMmprojGgufPressed,
                          icon: const Icon(Icons.file_open),
                          label: const Text('Open mmproj.gguf'),
                        ),
                        const SizedBox(width: 8),
                        const Tooltip(
                          message:
                              'Optional:\nModels that can also process images, multimodal models, also come with a mmproj.gguf file.',
                          child: Icon(Icons.info),
                        ),
                        if (_mmprojPath != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: SelectableText(
                              _mmprojPath!,
                              style: textStyle,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (kIsWeb) ...[
                    const Text(
                      'Web version powered by MLC & WebGPU',
                      style: textStyle,
                    ),
                    DropdownMenu(
                      initialSelection: _mlcModelId,
                      dropdownMenuEntries: [
                        ...[
                          MlcModelId.llama8b1k,
                          MlcModelId.openHermesMistral,
                          MlcModelId.phi3mini,
                          MlcModelId.qwen05b,
                          MlcModelId.tinyLlama,
                        ].map(
                          (modelId) {
                            return DropdownMenuEntry(
                              value: modelId,
                              label: modelId.toString(),
                            );
                          },
                        )
                      ],
                      onSelected: (value) {
                        setState(() {
                          _mlcModelId = value ?? _mlcModelId;
                        });
                      },
                    )
                  ],
                  spacerSmall,
                  if (_modelPath != null)
                    TextField(
                      controller: _controller,
                    ),
                  if (_mmprojPath != null && !kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                              onPressed: _openImagePressed,
                              icon: const Icon(Icons.image),
                              label: const Text('Open Image')),
                          const SizedBox(
                            width: 8,
                          ),
                          if (_imageBytes != null)
                            Text('Attached: ${_imageBytes!.length} bytes',
                                style: textStyle),
                        ],
                      ),
                    ),
                  const SizedBox(
                    height: 8,
                  ),
                  Row(
                    children: [
                      Tooltip(
                        message:
                            'Temperature controls the randomness of the output. Between 0.0 and 2.0, between 0.5 and 1.0 is recommended.',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                'Temperature: ${_temperature.toStringAsFixed(1)}',
                                style: textStyle),
                            const SizedBox(
                              width: 4,
                            ),
                            const Icon(
                              Icons.info,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Slider.adaptive(
                            label:
                                'Temperature: ${_temperature.toStringAsFixed(1)}',
                            value: _temperature,
                            max: 2.0,
                            onChanged: (newTemperature) {
                              setState(() {
                                _temperature = newTemperature;
                              });
                            }),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Tooltip(
                        message:
                            'Top P controls what percentiles of the probability distribution are considered when sampling the next token. Between 0.0 and 1.0, 1.0 is recommended.',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                'Top P: ${(_topP * 100).clamp(0, 100).round()}%',
                                style: textStyle),
                            const SizedBox(
                              width: 4,
                            ),
                            const Icon(
                              Icons.info,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Slider.adaptive(
                            label: 'Top P: ${(_topP * 100).clamp(0, 100)}%',
                            value: _topP,
                            max: 1.0,
                            onChanged: (newTopP) {
                              setState(() {
                                _topP = newTopP;
                              });
                            }),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_runningRequestId != null) {
                        fllamaCancelInference(_runningRequestId!);
                      } else {
                        _runInferencePressed();
                      }
                    },
                    child: _runningRequestId != null
                        ? const Text('Cancel')
                        : const Text('Run'),
                  ),
                  if (kIsWeb && _mlcDownloadProgress != null) ...[
                    const Text('Downloading model file...', style: textStyle),
                    LinearProgressIndicator(
                      value: _mlcDownloadProgress,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (kIsWeb && _mlcLoadProgress != null) ...[
                    const Text('Loading model...', style: textStyle),
                    LinearProgressIndicator(
                      value: _mlcLoadProgress,
                    ),
                    const SizedBox(height: 8),
                  ],
                  SelectableText(
                    latestResult,
                    style: textStyle,
                  ),
                  if (!kIsWeb && latestResult.isNotEmpty) ...[
                    spacerSmall,
                    Text('Output token count: $latestOutputTokenCount',
                        style: textStyle),
                  ],
                  if (latestChatTemplate.isNotEmpty) ...[
                    spacerSmall,
                    const Text('Chat template:', style: textStyle),
                    SelectableText(
                      latestChatTemplate,
                      style: textStyle,
                    ),
                  ],
                  if (latestBosToken.isNotEmpty) ...[
                    spacerSmall,
                    const Text('Beginning of sequence token:',
                        style: textStyle),
                    SelectableText(
                      latestBosToken,
                      style: textStyle,
                    ),
                  ],
                  if (latestEosToken.isNotEmpty) ...[
                    spacerSmall,
                    const Text('End of sequence token:', style: textStyle),
                    SelectableText(
                      latestEosToken,
                      style: textStyle,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  void _runInferencePressed() async {
    if (_modelPath == null) {
      SnackBar snackBar = const SnackBar(
        content: Text('Please open a .gguf file.'),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }
    var messageText = _controller.text;
    final isMultimodal = _mmprojPath != null;
    if (isMultimodal && _imageBytes != null) {
      messageText =
          '<img src="data:image/jpeg;base64,${base64Encode(_imageBytes!)}">\n\n$messageText';
    }
    // 2 choices:
    // 1. Inference directly. Chat template is *not* applied.
    //    A chat template defines start/end sigils for
    //    messages, which causes the model to recognize a
    //    a conversation.
    //
    // 2. Inference with chat template.

    // 1. Inference directly.
    // final request = FllamaInferenceRequest(
    //   maxTokens: 256,
    //   input: messageText,
    //   numGpuLayers: 99,
    //   modelPath: _modelPath!,
    //   penaltyFrequency: 0.0,
    //   // Don't use below 1.1, LLMs without a repeat penalty
    //   // will repeat the same token.
    //   penaltyRepeat: 1.1,
    //   topP: 1.0,
    //   contextSize: 2048,
    //   // Don't use 0.0, some models will repeat
    //   // the same token.
    //   temperature: 0.1,
    //   logger: (log) {
    //     // ignore: avoid_print
    //     print('[llama.cpp] $log');
    //   },
    // );
    // fllamaInferenceAsync(request, (String result, bool done) {
    //   setState(() {
    //     latestResult = result;
    //   });
    // });

    // 2. Inference with chat template.
    final request = OpenAiRequest(
      maxTokens: 100,
      messages: [
        Message(Role.user, messageText),
      ],
      numGpuLayers: 99,
      /* this seems to have no adverse effects in environments w/o GPU support, ex. Android and web */
      modelPath: kIsWeb ? _mlcModelId : _modelPath!,
      mmprojPath: _mmprojPath,
      frequencyPenalty: 0.0,
      // Don't use below 1.1, LLMs without a repeat penalty
      // will repeat the same token.
      presencePenalty: 1.1,
      topP: _topP,
      contextSize: 4096,
      // Don't use 0.0, some models will repeat
      // the same token.
      temperature: _temperature,
      logger: (log) {
        // ignore: avoid_print
        print('[llama.cpp] $log');
      },
    );

    if (kIsWeb) {
      final requestId =
          await fllamaChatMlcWeb(request, (downloadProgress, loadProgress) {
        setState(() {
          _mlcDownloadProgress = downloadProgress;
          _mlcLoadProgress = loadProgress;
          // ignore: avoid_print
          print(
              'Download progress: $downloadProgress, Load progress: $loadProgress');
        });
      }, (response, done) {
        setState(() {
          _mlcDownloadProgress = null;
          _mlcLoadProgress = null;
          latestResult = response;
          if (done) {
            _runningRequestId = null;
          }
        });
      });
      setState(() {
        _runningRequestId = requestId;
      });
      return;
    }

    final chatTemplate = await fllamaChatTemplateGet(_modelPath!);
    setState(() {
      latestChatTemplate = chatTemplate;
    });

    final eosToken = await fllamaEosTokenGet(_modelPath!);
    setState(() {
      latestEosToken = eosToken;
    });

    final bosToken = await fllamaBosTokenGet(_modelPath!);
    setState(() {
      latestBosToken = bosToken;
    });

    int requestId = await fllamaChat(request, (response, done) {
      setState(() {
        latestResult = response;
        fllamaTokenize(FllamaTokenizeRequest(
                input: latestResult, modelPath: _modelPath!))
            .then((value) {
          setState(() {
            latestOutputTokenCount = value;
          });
        });
        if (done) {
          _runningRequestId = null;
        }
      });
    });
    setState(() {
      _runningRequestId = requestId;
    });
  }

  void _openGgufPressed() async {
    final filePath = await _pickGgufPath();
    if (filePath == null) {
      await kSharedPrefs.remove(kModelPathKey);
      return;
    } else {
      await kSharedPrefs.setString(kModelPathKey, filePath);
    }

    setState(() {
      _modelPath = filePath;
    });
  }

  void _openMmprojGgufPressed() async {
    final filePath = await _pickGgufPath();
    if (filePath == null) {
      await kSharedPrefs.remove(kMmprojPathKey);
      return;
    } else {
      await kSharedPrefs.setString(kMmprojPathKey, filePath);
    }

    setState(() {
      _mmprojPath = filePath;
    });
  }

  void _openImagePressed() async {
    final filePath = await _pickImagePath();
    if (filePath == null) {
      return;
    }
    final bytes = await File(filePath).readAsBytes();
    setState(() {
      _imageBytes = bytes;
    });
  }
}

Future<String?> _pickGgufPath() async {
  if (!kIsWeb && TargetPlatform.android == defaultTargetPlatform) {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    return result?.files.first.path;
  }

  final file = await openFile(acceptedTypeGroups: <XTypeGroup>[
    const XTypeGroup(
      label: '.gguf',
      extensions: ['gguf'],
      // UTIs are required for iOS, which does not have a .gguf UTI.
      uniformTypeIdentifiers: [],
    ),
  ]);

  if (file == null) {
    return null;
  }
  final filePath = file.path;
  return filePath;
}

Future<String?> _pickImagePath() async {
  final file = await openFile(acceptedTypeGroups: <XTypeGroup>[
    const XTypeGroup(
      label: '.jpeg',
      extensions: ['jpeg'],
      uniformTypeIdentifiers: [
        'public.jpeg',
        'public.image',
      ],
    ),
    const XTypeGroup(label: '.png', extensions: [
      'png'
    ], uniformTypeIdentifiers: [
      'public.png',
      'public.image',
    ])
  ]);

  if (file == null) {
    return null;
  }
  final filePath = file.path;
  return filePath;
}
