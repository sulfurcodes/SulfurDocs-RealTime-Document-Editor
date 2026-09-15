import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/document_model.dart';
import 'package:frontend/widgets/loader.dart';
import 'package:routemaster/routemaster.dart';
import 'package:frontend/providers/auth_repository_provider.dart';
import 'package:frontend/providers/document_repository_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/data/avatars.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late Future<Map<String, dynamic>> documentsFuture;

  @override
  void initState() {
    super.initState();
    documentsFuture = ref.read(documentRepositoryProvider).getDocuments();
  }

  void refreshDocuments() {
    setState(() {
      documentsFuture = ref.read(documentRepositoryProvider).getDocuments();
    });
  }

  Future<void> signOut(WidgetRef ref) async {
    final authRepo = ref.read(authRepositoryProvider);

    await authRepo.signOut();

    if (!mounted) return;

    ref.read(userProvider.notifier).logout();
  }

  Future<void> createDocument(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(documentRepositoryProvider)
          .createDocument();

      if (result['success']) {
        final document = result['document'];

        await Routemaster.of(context).push('/document/${document['_id']}');

        refreshDocuments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to create document'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            final user = ref.watch(userProvider).user;
            final pfpId = user?['pfp'];

            final avatar = avatars.firstWhere(
              (avatar) => avatar.id == pfpId,
              orElse: () => avatars.first,
            );

            return Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () {},
                child: ClipOval(
                  child: Image.asset(avatar.asset, fit: BoxFit.cover),
                ),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () => createDocument(context, ref),
            icon: const Icon(Icons.add, color: Colors.black),
          ),
          IconButton(
            onPressed: () => signOut(ref),
            icon: const Icon(Icons.logout, color: Colors.red),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: documentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Loader();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No documents found'));
          }

          final documents = snapshot.data!['documents'] as List<DocumentModel>;

          if (documents.isEmpty) {
            return const Center(child: Text('No documents yet'));
          }

          return Center(
            child: Container(
              width: isPhone
                  ? double.infinity
                  : screenWidth > 800
                  ? 600
                  : screenWidth * 0.9,
              margin: EdgeInsets.all(isPhone ? 8 : 10),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: isPhone ? 4 : 8),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final DocumentModel document = documents[index];

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: isPhone ? 5 : 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(10),
                      side: BorderSide(
                        color: Colors.black,
                        width: 0.18,
                      )
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isPhone ? 14 : 16,
                        vertical: isPhone ? 4 : 6,
                      ),
                      title: Text(
                        document.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17),
                      ),
                      onTap: () async {
                        await Routemaster.of(context)
                            .push('/document/${document.id}');

                        refreshDocuments();
                      },
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
