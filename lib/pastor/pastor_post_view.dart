import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'bible_structure.dart';
import 'pastor_theme.dart';

const String _esvApiKey = '32a3517151fac42dbdbc20f31567c3cf6e5d9053';
const String _apiBibleKey = 'qyYbBHer804iRVqMup8ff';

const Map<String, String> _apiBibleVersions = {
  'KJV': 'de4e12af7f28f599-02',
  'ASV': '06125adad2d5898a-01',
  'WEB': '9879dbb7cfe39e4d-04',
  'BBE': '40072c4a5aba4022-01',
};

class PastorPostView extends StatefulWidget {
  const PastorPostView({super.key});

  @override
  State<PastorPostView> createState() => _PastorPostViewState();
}

class _PastorPostViewState extends State<PastorPostView> {
  final wordCtrl = TextEditingController();
  final youthCtrl = TextEditingController();

  bool postingWord = false;
  bool postingYouth = false;

  File? wordImage;
  File? youthImage;

  // Upload progress: 0.0 to 1.0, null = not uploading
  double? wordUploadProgress;
  double? youthUploadProgress;

  final picker = ImagePicker();

  // ─── ESV ───────────────────────────────────────────────
  Future<String?> fetchEsvVerse(String reference) async {
    try {
      final uri = Uri.parse(
        'https://api.esv.org/v3/passage/text/'
        '?q=${Uri.encodeComponent(reference)}'
        '&include-headings=false'
        '&include-footnotes=false'
        '&include-verse-numbers=false'
        '&include-short-copyright=false'
        '&include-passage-references=false'
        '&indent-poetry=false',
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Token $_esvApiKey'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final passages = data['passages'] as List<dynamic>?;
        if (passages != null && passages.isNotEmpty) {
          return passages[0].toString().trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── API.Bible ─────────────────────────────────────────
  Future<String?> fetchApiBibleVerse(
    String bibleId,
    String book,
    int chapter,
    int verse,
  ) async {
    try {
      final usfm = _bookToUsfm(book);
      if (usfm == null) return null;
      final verseId = '$usfm.$chapter.$verse';
      final uri = Uri.parse(
        'https://api.scripture.api.bible/v1/bibles/$bibleId/verses/$verseId'
        '?content-type=text'
        '&include-notes=false'
        '&include-titles=false'
        '&include-chapter-numbers=false'
        '&include-verse-numbers=false'
        '&include-verse-spans=false',
      );
      final response = await http.get(uri, headers: {'api-key': _apiBibleKey});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['data']?['content'] as String?;
        if (content != null) {
          return content
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('¶', '')
              .trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _bookToUsfm(String book) {
    const map = {
      'Genesis': 'GEN',
      'Exodus': 'EXO',
      'Leviticus': 'LEV',
      'Numbers': 'NUM',
      'Deuteronomy': 'DEU',
      'Joshua': 'JOS',
      'Judges': 'JDG',
      'Ruth': 'RUT',
      '1 Samuel': '1SA',
      '2 Samuel': '2SA',
      '1 Kings': '1KI',
      '2 Kings': '2KI',
      '1 Chronicles': '1CH',
      '2 Chronicles': '2CH',
      'Ezra': 'EZR',
      'Nehemiah': 'NEH',
      'Esther': 'EST',
      'Job': 'JOB',
      'Psalms': 'PSA',
      'Proverbs': 'PRO',
      'Ecclesiastes': 'ECC',
      'Song of Solomon': 'SNG',
      'Isaiah': 'ISA',
      'Jeremiah': 'JER',
      'Lamentations': 'LAM',
      'Ezekiel': 'EZK',
      'Daniel': 'DAN',
      'Hosea': 'HOS',
      'Joel': 'JOL',
      'Amos': 'AMO',
      'Obadiah': 'OBA',
      'Jonah': 'JON',
      'Micah': 'MIC',
      'Nahum': 'NAM',
      'Habakkuk': 'HAB',
      'Zephaniah': 'ZEP',
      'Haggai': 'HAG',
      'Zechariah': 'ZEC',
      'Malachi': 'MAL',
      'Matthew': 'MAT',
      'Mark': 'MRK',
      'Luke': 'LUK',
      'John': 'JHN',
      'Acts': 'ACT',
      'Romans': 'ROM',
      '1 Corinthians': '1CO',
      '2 Corinthians': '2CO',
      'Galatians': 'GAL',
      'Ephesians': 'EPH',
      'Philippians': 'PHP',
      'Colossians': 'COL',
      '1 Thessalonians': '1TH',
      '2 Thessalonians': '2TH',
      '1 Timothy': '1TI',
      '2 Timothy': '2TI',
      'Titus': 'TIT',
      'Philemon': 'PHM',
      'Hebrews': 'HEB',
      'James': 'JAS',
      '1 Peter': '1PE',
      '2 Peter': '2PE',
      '1 John': '1JN',
      '2 John': '2JN',
      '3 John': '3JN',
      'Jude': 'JUD',
      'Revelation': 'REV',
    };
    return map[book];
  }

  // ─── Image Picker ──────────────────────────────────────
  Future<void> pickImage({required bool isWord}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 75, // ✅ compress to reduce upload size
        maxWidth: 1280, // ✅ cap resolution — avoids huge files
        maxHeight: 1280,
      );

      if (picked != null) {
        final file = File(picked.path);
        // ✅ Sanity check — file must actually exist
        if (!await file.exists()) {
          _showError('Could not read image file. Try again.');
          return;
        }
        setState(() {
          if (isWord) {
            wordImage = file;
          } else {
            youthImage = file;
          }
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  // ✅ Upload with real progress tracking using UploadTask
  Future<String?> uploadImage(
    File file,
    String folder, {
    required bool isWord,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(
        '$folder/${user?.uid}/$fileName',
      );

      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = ref.putFile(file, metadata);

      // ✅ Listen to progress and update UI
      uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted) return;
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        setState(() {
          if (isWord) {
            wordUploadProgress = progress;
          } else {
            youthUploadProgress = progress;
          }
        });
      });

      // ✅ Await completion
      final snapshot = await uploadTask;

      // ✅ Clear progress
      if (mounted) {
        setState(() {
          if (isWord) {
            wordUploadProgress = null;
          } else {
            youthUploadProgress = null;
          }
        });
      }

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isWord) {
            wordUploadProgress = null;
          } else {
            youthUploadProgress = null;
          }
        });
        _showError('Image upload failed: $e');
      }
      return null;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  // ─── Verse Selector ────────────────────────────────────
  void openVerseSelector(TextEditingController controller) {
    String? book;
    int? chapter;
    int? verse;
    List<int> chapters = [];
    List<int> verses = [];
    bool fetchingVerse = false;
    String? fetchError;

    String selectedVersion = 'ESV';
    final allVersions = ['ESV', ..._apiBibleVersions.keys];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Select Bible Verse",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: selectedVersion,
                    decoration: const InputDecoration(
                      labelText: "Bible Version",
                      border: OutlineInputBorder(),
                    ),
                    items: allVersions
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setModalState(() {
                      selectedVersion = v!;
                      fetchError = null;
                    }),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    hint: const Text("Book"),
                    initialValue: book,
                    items: bibleStructure.keys
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) => setModalState(() {
                      book = v;
                      chapter = null;
                      verse = null;
                      fetchError = null;
                      chapters = List.generate(
                        bibleStructure[book]!.length,
                        (i) => i + 1,
                      );
                      verses = [];
                    }),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<int>(
                    hint: const Text("Chapter"),
                    initialValue: chapter,
                    items: chapters
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text("$c")),
                        )
                        .toList(),
                    onChanged: (v) => setModalState(() {
                      chapter = v;
                      verse = null;
                      fetchError = null;
                      verses = List.generate(
                        bibleStructure[book]![chapter! - 1],
                        (i) => i + 1,
                      );
                    }),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<int>(
                    hint: const Text("Verse"),
                    initialValue: verse,
                    items: verses
                        .map(
                          (v) => DropdownMenuItem(value: v, child: Text("$v")),
                        )
                        .toList(),
                    onChanged: (v) => setModalState(() {
                      verse = v;
                      fetchError = null;
                    }),
                  ),
                  const SizedBox(height: 16),

                  if (fetchError != null) ...[
                    Text(
                      fetchError!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                  ],

                  ElevatedButton(
                    onPressed: fetchingVerse
                        ? null
                        : () async {
                            if (book == null ||
                                chapter == null ||
                                verse == null) {
                              return;
                            }

                            final reference = "$book $chapter:$verse";
                            setModalState(() {
                              fetchingVerse = true;
                              fetchError = null;
                            });

                            String? verseText;
                            if (selectedVersion == 'ESV') {
                              verseText = await fetchEsvVerse(reference);
                            } else {
                              final bibleId =
                                  _apiBibleVersions[selectedVersion]!;
                              verseText = await fetchApiBibleVerse(
                                bibleId,
                                book!,
                                chapter!,
                                verse!,
                              );
                            }

                            if (verseText != null && verseText.isNotEmpty) {
                              controller.text =
                                  "$reference ($selectedVersion)\n$verseText";
                              if (context.mounted) Navigator.pop(context);
                            } else {
                              setModalState(() {
                                fetchingVerse = false;
                                fetchError =
                                    "Could not fetch verse. Try another version.";
                              });
                            }
                          },
                    child: fetchingVerse
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Insert Verse"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Post Word ─────────────────────────────────────────
  Future<void> postWord() async {
    if (wordCtrl.text.trim().isEmpty && wordImage == null) return;
    setState(() => postingWord = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      String? imageUrl;

      if (wordImage != null) {
        imageUrl = await uploadImage(
          wordImage!,
          'post_images/daily',
          isWord: true,
        );
        // ✅ If upload failed, don't post
        if (imageUrl == null && wordImage != null) {
          setState(() => postingWord = false);
          return;
        }
      }

      await FirebaseFirestore.instance.collection("daily_messages").add({
        "text": wordCtrl.text.trim(),
        "imageUrl": imageUrl,
        "createdAt": FieldValue.serverTimestamp(),
        "createdBy": user?.uid,
        "createdByEmail": user?.email,
      });

      wordCtrl.clear();
      setState(() {
        postingWord = false;
        wordImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Daily Word posted!')));
      }
    } catch (e) {
      setState(() => postingWord = false);
      _showError('Failed to post: $e');
    }
  }

  // ─── Post Youth ────────────────────────────────────────
  Future<void> postYouth() async {
    if (youthCtrl.text.trim().isEmpty && youthImage == null) return;
    setState(() => postingYouth = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      String? imageUrl;

      if (youthImage != null) {
        imageUrl = await uploadImage(
          youthImage!,
          'post_images/youth',
          isWord: false,
        );
        if (imageUrl == null && youthImage != null) {
          setState(() => postingYouth = false);
          return;
        }
      }

      await FirebaseFirestore.instance.collection("youth_words").add({
        "text": youthCtrl.text.trim(),
        "imageUrl": imageUrl,
        "createdAt": FieldValue.serverTimestamp(),
        "createdBy": user?.uid,
        "createdByEmail": user?.email,
      });

      youthCtrl.clear();
      setState(() {
        postingYouth = false;
        youthImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Youth Word posted!')));
      }
    } catch (e) {
      setState(() => postingYouth = false);
      _showError('Failed to post: $e');
    }
  }

  // ─── Image Preview Widget ──────────────────────────────
  Widget _imagePreview(File? image, bool isWord) {
    final progress = isWord ? wordUploadProgress : youthUploadProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image != null) ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  image,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              // ✅ Upload progress overlay
              if (progress != null)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ✅ Remove button — hidden while uploading
              if (progress == null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      if (isWord) {
                        wordImage = null;
                      } else {
                        youthImage = null;
                      }
                    }),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // ✅ Hide picker button while uploading
        if (progress == null)
          OutlinedButton.icon(
            onPressed: () => pickImage(isWord: isWord),
            icon: const Icon(Icons.image),
            label: Text(image == null ? "Add Image" : "Change Image"),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PastorSurface(
      padding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ComposerTitle(
                    icon: Icons.wb_sunny_rounded,
                    title: "Daily Word",
                    color: PastorColors.gold,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: wordCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Type message or insert verse",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.menu_book_rounded),
                        tooltip: "Insert Verse",
                        onPressed: () => openVerseSelector(wordCtrl),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _imagePreview(wordImage, true),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: postingWord ? null : postWord,
                      child: postingWord
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  wordUploadProgress != null
                                      ? 'Uploading ${(wordUploadProgress! * 100).toInt()}%...'
                                      : 'Posting...',
                                ),
                              ],
                            )
                          : const Text("Post Word"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ComposerTitle(
                    icon: Icons.groups_rounded,
                    title: "Youth Word",
                    color: PastorColors.coral,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: youthCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Type youth message or insert verse",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.menu_book_rounded),
                        tooltip: "Insert Verse",
                        onPressed: () => openVerseSelector(youthCtrl),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _imagePreview(youthImage, false),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: postingYouth ? null : postYouth,
                      child: postingYouth
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  youthUploadProgress != null
                                      ? 'Uploading ${(youthUploadProgress! * 100).toInt()}%...'
                                      : 'Posting...',
                                ),
                              ],
                            )
                          : const Text("Post Youth Word"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _ComposerTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: PastorColors.ink,
          ),
        ),
      ],
    );
  }
}
