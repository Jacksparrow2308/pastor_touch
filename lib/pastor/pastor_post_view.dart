import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PastorPostView extends StatefulWidget {
  const PastorPostView({super.key});

  @override
  State<PastorPostView> createState() => _PastorPostViewState();
}

class _PastorPostViewState extends State<PastorPostView> {

  static const String youthWordCollectionPath = 'youth_words';
  static const String wordCollectionPath = 'daily_messages';

  final youthWordCtrl = TextEditingController();
  final wordCtrl = TextEditingController();

  bool postingYouthWord = false;
  bool postingWord = false;
  bool fetchingVerse = false;

  static const String esvToken = "YOUR_ESV_TOKEN_HERE";

  // =========================
  // BIBLE DATA
  // =========================

  final List<String> bibleBooks = [
    "Genesis","Exodus","Leviticus","Numbers","Deuteronomy",
    "Joshua","Judges","Ruth",
    "1 Samuel","2 Samuel",
    "1 Kings","2 Kings",
    "1 Chronicles","2 Chronicles",
    "Ezra","Nehemiah","Esther",
    "Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon",
    "Isaiah","Jeremiah","Lamentations",
    "Ezekiel","Daniel",
    "Hosea","Joel","Amos","Obadiah","Jonah",
    "Micah","Nahum","Habakkuk","Zephaniah",
    "Haggai","Zechariah","Malachi",
    "Matthew","Mark","Luke","John",
    "Acts","Romans",
    "1 Corinthians","2 Corinthians",
    "Galatians","Ephesians","Philippians","Colossians",
    "1 Thessalonians","2 Thessalonians",
    "1 Timothy","2 Timothy",
    "Titus","Philemon",
    "Hebrews","James",
    "1 Peter","2 Peter",
    "1 John","2 John","3 John",
    "Jude","Revelation"
  ];

  String? selectedBook;
  int? selectedChapter;
  int? selectedVerse;
  String selectedVersion = "ESV";

  // =========================
  // FETCH VERSE
  // =========================

  Future<void> fetchVerse() async {

    if (selectedBook == null ||
        selectedChapter == null ||
        selectedVerse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select book, chapter and verse")),
      );
      return;
    }

    setState(() => fetchingVerse = true);

    try {

      final query =
          "$selectedBook+$selectedChapter:$selectedVerse";

      if (selectedVersion == "ESV") {

        final response = await http.get(
          Uri.parse(
              "https://api.esv.org/v3/passage/text/?q=$query"),
          headers: {
            "Authorization": "Token $esvToken",
          },
        );

        final data = json.decode(response.body);
        wordCtrl.text = data["passages"][0];

      } else {
        wordCtrl.text =
            "$query ($selectedVersion)\n\nVersion not connected yet.";
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e")),
      );
    } finally {
      setState(() => fetchingVerse = false);
    }
  }

  // =========================
  // POST TO FIRESTORE
  // =========================

  Future<void> postToBackend({
    required String category,
    required String collectionPath,
    required TextEditingController controller,
  }) async {

    final text = controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please type something")),
      );
      return;
    }

    setState(() {
      if (category == 'youth_word') {
        postingYouthWord = true;
      } else {
        postingWord = true;
      }
    });

    try {

      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance
          .collection(collectionPath)
          .add({
        'category': category,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.uid,
        'createdByEmail': user?.email,
      });

      controller.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Posted")));

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Post failed: $e")));
    } finally {
      if (mounted) {
        setState(() {
          if (category == 'youth_word') {
            postingYouthWord = false;
          } else {
            postingWord = false;
          }
        });
      }
    }
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // =====================
          // BIBLE SELECTOR CARD
          // =====================

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [

                  const Text(
                    "Select Bible Verse",
                    style: TextStyle(
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: selectedBook,
                    hint: const Text("Select Book"),
                    items: bibleBooks
                        .map((book) =>
                            DropdownMenuItem(
                              value: book,
                              child: Text(book),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedBook = value;
                        selectedChapter = null;
                        selectedVerse = null;
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<int>(
                    value: selectedChapter,
                    hint: const Text("Select Chapter"),
                    items: List.generate(
                            150, (index) => index + 1)
                        .map((c) =>
                            DropdownMenuItem(
                              value: c,
                              child: Text(c.toString()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedChapter = value;
                        selectedVerse = null;
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<int>(
                    value: selectedVerse,
                    hint: const Text("Select Verse"),
                    items: List.generate(
                            176, (index) => index + 1)
                        .map((v) =>
                            DropdownMenuItem(
                              value: v,
                              child: Text(v.toString()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedVerse = value;
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: selectedVersion,
                    items: ["ESV", "KJV", "NIV"]
                        .map((version) =>
                            DropdownMenuItem(
                              value: version,
                              child: Text(version),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedVersion = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed:
                        fetchingVerse ? null : fetchVerse,
                    child: fetchingVerse
                        ? const CircularProgressIndicator()
                        : const Text("Fetch Verse"),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          _PostSection(
            title: "Post Youth Word",
            hintText: "Type youth word...",
            collectionPath: youthWordCollectionPath,
            controller: youthWordCtrl,
            busy: postingYouthWord,
            onPost: () => postToBackend(
              category: "youth_word",
              collectionPath:
                  youthWordCollectionPath,
              controller: youthWordCtrl,
            ),
          ),

          const SizedBox(height: 12),

          _PostSection(
            title: "Post Word",
            hintText: "Fetched verse will appear here...",
            collectionPath: wordCollectionPath,
            controller: wordCtrl,
            busy: postingWord,
            onPost: () => postToBackend(
              category: "word",
              collectionPath: wordCollectionPath,
              controller: wordCtrl,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostSection extends StatelessWidget {
  final String title;
  final String hintText;
  final String collectionPath;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onPost;

  const _PostSection({
    required this.title,
    required this.hintText,
    required this.collectionPath,
    required this.controller,
    required this.busy,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                      fontWeight:
                          FontWeight.bold),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: hintText,
                border:
                    const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: busy ? null : onPost,
              child: busy
                  ? const CircularProgressIndicator()
                  : const Text("Post"),
            ),
          ],
        ),
      ),
    );
  }
}
