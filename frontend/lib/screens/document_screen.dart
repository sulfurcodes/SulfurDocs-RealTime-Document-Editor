import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:frontend/providers/document_repository_provider.dart';
import 'package:frontend/models/document_model.dart';
import 'package:frontend/repositories/socket_repository.dart';
import 'package:routemaster/routemaster.dart';
import 'package:frontend/providers/user_provider.dart';

import 'dart:async';

class DocumentScreen extends ConsumerStatefulWidget {
  final String id;
  const DocumentScreen({Key? key, required this.id}) : super(key: key);

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  final TextEditingController nameController = TextEditingController(
    text: 'Untitled Document',
  );

  final QuillController quillController = QuillController.basic();
  SocketRepository? socketRepository;
  StreamSubscription? _localChangesSub;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repository = SocketRepository();
      socketRepository = repository;
      repository.connectFromStorage();
      repository.joinRoom(widget.id);
      repository.changeListener((data) {
        debugPrint('RECEIVED CHANGES: $data');
        if (!mounted) {
          return;
        }
        final delta = data['delta'];
        if (delta is List) {
          quillController.compose(
            Delta.fromJson(delta),
            quillController.selection,
            ChangeSource.remote,
          );
        }
      });

      fetchDocumentData();

      _autoSaveTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final repository = socketRepository;
        if (repository == null) {
          return;
        }
        repository.autoSave({
          'delta': quillController.document.toDelta().toJson(),
          'documentId': widget.id,
        });
      });
    });
  }

  void _attachLocalChangesListener() {
    _localChangesSub?.cancel();
    _localChangesSub = quillController.document.changes.listen((event) {
      if (event.source == ChangeSource.local) {
        debugPrint('SENDING TYPING: ${event.change}');
        final repository = socketRepository;
        if (repository == null) {
          return;
        }
        final data = <String, dynamic>{
          'delta': event.change.toJson(),
          'room': widget.id,
        };
        repository.typing(data);
      }
    });
  }

  Future<void> fetchDocumentData() async {
    final result = await ref
        .read(documentRepositoryProvider)
        .getDocument(id: widget.id);

    if (result['success']) {
      final DocumentModel document = result['document'];
      final quillDocument = document.content.isNotEmpty
          ? Document.fromJson(document.content)
          : Document();
      quillController.document = quillDocument;
      _attachLocalChangesListener();
      if (mounted) {
        setState(() {
          nameController.text = document.title;
        });
      }
    } else {
      debugPrint('DOCUMENT LOAD FAILED: ${result['message']}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load document'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _localChangesSub?.cancel();
    socketRepository?.dispose();
    nameController.dispose();
    quillController.dispose();

    super.dispose();
  }

  Future<void> nameDocument(String name) async {
    final result = await ref
        .read(documentRepositoryProvider)
        .nameDocuments(id: widget.id, title: name);

    if (!mounted) return;

    if (result['success']) {
      final DocumentModel updatedDocument = result['document'];
      print(updatedDocument.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: isPhone ? 60 : 64,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade800, width: 0.1),
            ),
          ),
        ),
        titleSpacing: isPhone ? 10 : 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Routemaster.of(context).replace('/');
              },
              child: Image.asset(
                'assets/logo/docs-logo.png',
                height: isPhone ? 28 : 30,
                width: isPhone ? 21 : 23,
              ),
            ),
            SizedBox(width: isPhone ? 8 : 10),
            Expanded(
              child: TextField(
                controller: nameController,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    nameDocument(value.trim());
                  }
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color.fromRGBO(26, 115, 232, 1),
                    ),
                  ),
                  contentPadding: EdgeInsets.only(left: isPhone ? 6 : 10),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.all(isPhone ? 7 : 10),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(
                Icons.lock,
                size: isPhone ? 14 : 16,
                color: Colors.white,
              ),
              label: Text(
                'Share',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isPhone ? 13 : 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(26, 115, 232, 1),
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: isPhone ? 10 : 14,
                  vertical: isPhone ? 8 : 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: isPhone ? 6 : 10),

            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: isPhone ? 4 : 10),
                child: QuillSimpleToolbar(
                  controller: quillController,
                  config: const QuillSimpleToolbarConfig(
                    showFontFamily: true,
                    showFontSize: true,
                    showColorButton: true,
                    showBackgroundColorButton: true,
                    buttonOptions: QuillSimpleToolbarButtonOptions(
                      fontFamily: QuillToolbarFontFamilyButtonOptions(
                        items: <String, String>{
                          'Ibarra Real Nova': 'ibarra-real-nova',
                          'SquarePeg': 'square-peg',
                          'Nunito': 'nunito',
                          'Pacifico': 'pacifico',
                          'Roboto Mono': 'roboto-mono',
                        },
                      ),
                      fontSize: QuillToolbarFontSizeButtonOptions(
                        items: {
                          'Small': '12',
                          'Large': '24',
                          'Huge': '32',
                          'Clear': '18',
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: Container(
                width: isPhone
                    ? double.infinity
                    : screenWidth > 1100
                    ? 1000
                    : screenWidth * 0.9,
                margin: EdgeInsets.symmetric(
                  horizontal: isPhone ? 6 : 16,
                  vertical: isPhone ? 6 : 10,
                ),
                child: Card(
                  color: Colors.white,
                  elevation: 5,
                  child: Padding(
                    padding: EdgeInsets.all(isPhone ? 16 : 30),
                    child: QuillEditor.basic(
                      controller: quillController,
                      config: const QuillEditorConfig(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
