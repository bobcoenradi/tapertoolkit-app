import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/journal_entry_model.dart';
import '../models/taper_plan_model.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─── Journal entries ──────────────────────────────────────────────────────

  static Future<void> saveJournalEntry(JournalEntry entry) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('journal')
        .doc(entry.dateKey);
    await ref.set(entry.toMap());
  }

  static Future<List<JournalEntry>> fetchJournalEntries() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('journal')
        .orderBy('date', descending: true)
        .limit(90)
        .get();
    return snap.docs
        .map((d) => JournalEntry.fromMap(d.data(), d.id))
        .toList();
  }

  static Future<JournalEntry?> fetchEntryForDate(DateTime date) async {
    final uid = _uid;
    if (uid == null) return null;
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('journal')
        .doc(key)
        .get();
    if (!doc.exists) return null;
    return JournalEntry.fromMap(doc.data()!, doc.id);
  }

  // ─── Appointments ─────────────────────────────────────────────────────────

  static Future<void> saveAppointment(Appointment appt) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = appt.id.isEmpty
        ? _db.collection('users').doc(uid).collection('appointments').doc()
        : _db.collection('users').doc(uid).collection('appointments').doc(appt.id);
    await ref.set(appt.toMap());
  }

  static Future<List<Appointment>> fetchUpcomingAppointments() async {
    final uid = _uid;
    if (uid == null) return [];
    final now = DateTime.now().toIso8601String();
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: now)
        .orderBy('dateTime')
        .limit(20)
        .get();
    return snap.docs
        .map((d) => Appointment.fromMap(d.data(), d.id))
        .toList();
  }

  static Future<void> deleteAppointment(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('appointments').doc(id).delete();
  }

  // ─── Meds ─────────────────────────────────────────────────────────────────

  static Future<void> saveMedReminder(MedReminder med) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = med.id.isEmpty
        ? _db.collection('users').doc(uid).collection('meds').doc()
        : _db.collection('users').doc(uid).collection('meds').doc(med.id);
    await ref.set(med.toMap());
  }

  static Future<List<MedReminder>> fetchMedReminders() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('meds')
        .get();
    return snap.docs
        .map((d) => MedReminder.fromMap(d.data(), d.id))
        .toList();
  }

  static Future<void> deleteMedReminder(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('meds').doc(id).delete();
  }

  // ─── Dose log (taper progress) ────────────────────────────────────────────

  static Future<void> logDose(double dose) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'currentDose': dose});
    // Also store a time-series log entry
    await _db
        .collection('users')
        .doc(uid)
        .collection('doseLog')
        .add({'dose': dose, 'loggedAt': DateTime.now().toIso8601String()});
  }

  static Future<List<Map<String, dynamic>>> fetchDoseLog() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('doseLog')
        .orderBy('loggedAt')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ─── Taper plans ──────────────────────────────────────────────────────────

  static Future<String> saveTaperPlan(TaperPlan plan) async {
    final uid = _uid;
    if (uid == null) return '';
    final ref = plan.id.isEmpty
        ? _db.collection('users').doc(uid).collection('taperPlans').doc()
        : _db.collection('users').doc(uid).collection('taperPlans').doc(plan.id);
    await ref.set(plan.toMap());
    return ref.id;
  }

  static Future<TaperPlan?> fetchActiveTaperPlan() async {
    final uid = _uid;
    if (uid == null) return null;
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('taperPlans')
        .where('status', whereIn: ['active', 'hold'])
        .orderBy('startDate', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return TaperPlan.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  static Future<void> updateTaperPlanStatus(
      String planId, String status, int holdAtStepIndex) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('taperPlans')
        .doc(planId)
        .update({'status': status, 'holdAtStepIndex': holdAtStepIndex});
  }

  // Mark today's dose as taken (separate from the taper progress doseLog)
  static Future<void> logDoseTaken(double dose) async {
    final uid = _uid;
    if (uid == null) return;
    final today = DateTime.now();
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _db
        .collection('users')
        .doc(uid)
        .collection('doseTaken')
        .doc(key)
        .set({'dose': dose, 'takenAt': today.toIso8601String()});
    // Also write to the time-series doseLog for the chart
    await _db
        .collection('users')
        .doc(uid)
        .collection('doseLog')
        .add({'dose': dose, 'loggedAt': today.toIso8601String()});
  }

  static Future<bool> isDoseTakenToday() async {
    final uid = _uid;
    if (uid == null) return false;
    final today = DateTime.now();
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('doseTaken')
        .doc(key)
        .get();
    return doc.exists;
  }

  // ─── Backfill author photo on existing posts & comments ──────────────────

  static Future<void> backfillAuthorPhoto({
    required String nickname,
    required String authorPhotoUrl,
  }) async {
    // Update all posts by this nickname
    final postSnap = await _db
        .collection('communityPosts')
        .where('nickname', isEqualTo: nickname)
        .get();

    final batch = _db.batch();
    for (final doc in postSnap.docs) {
      batch.update(doc.reference, {'authorPhotoUrl': authorPhotoUrl});

      // Update all comments inside each post by this nickname
      final commentSnap = await doc.reference
          .collection('comments')
          .where('nickname', isEqualTo: nickname)
          .get();
      for (final c in commentSnap.docs) {
        batch.update(c.reference, {'authorPhotoUrl': authorPhotoUrl});
      }
    }
    await batch.commit();
  }

  // ─── Community posts ──────────────────────────────────────────────────────

  static Future<String> createPost({
    required String nickname,
    required String topicId,
    required String title,
    required String content,
    String? imageUrl,
    String? authorPhotoUrl,
  }) async {
    final ref = await _db.collection('communityPosts').add({
      'nickname': nickname,
      'topicId': topicId,
      'title': title,
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
      'likes': 0,
      'commentCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return ref.id;
  }

  /// Fetch a page of posts for a topic. Pass [lastDoc] for subsequent pages.
  static Future<({List<Map<String, dynamic>> posts, DocumentSnapshot? lastDoc})>
      fetchPostsPaginated({
    required String topicId,
    int pageSize = 15,
    DocumentSnapshot? lastDoc,
  }) async {
    Query q = _db
        .collection('communityPosts')
        .where('topicId', isEqualTo: topicId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize);
    if (lastDoc != null) q = q.startAfterDocument(lastDoc);
    final snap = await q.get();
    final posts = snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
    return (posts: posts, lastDoc: snap.docs.isEmpty ? null : snap.docs.last);
  }

  static Future<void> likePost(String postId) async {
    await _db.collection('communityPosts').doc(postId).update({
      'likes': FieldValue.increment(1),
    });
  }

  // ─── Comments ─────────────────────────────────────────────────────────────

  static Future<void> createComment({
    required String postId,
    required String nickname,
    required String content,
    String? authorPhotoUrl,
  }) async {
    final batch = _db.batch();
    final commentRef = _db
        .collection('communityPosts')
        .doc(postId)
        .collection('comments')
        .doc();
    batch.set(commentRef, {
      'nickname': nickname,
      'content': content,
      if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
      'likes': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
    batch.update(_db.collection('communityPosts').doc(postId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  static Future<({List<Map<String, dynamic>> comments, DocumentSnapshot? lastDoc})>
      fetchCommentsPaginated({
    required String postId,
    int pageSize = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    Query q = _db
        .collection('communityPosts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .limit(pageSize);
    if (lastDoc != null) q = q.startAfterDocument(lastDoc);
    final snap = await q.get();
    final comments = snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
    return (comments: comments, lastDoc: snap.docs.isEmpty ? null : snap.docs.last);
  }

  static Future<void> deletePost(String postId) async {
    await _db.collection('communityPosts').doc(postId).delete();
  }

  static Future<void> deleteComment({required String postId, required String commentId}) async {
    final batch = _db.batch();
    batch.delete(_db.collection('communityPosts').doc(postId).collection('comments').doc(commentId));
    batch.update(_db.collection('communityPosts').doc(postId), {
      'commentCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  // ─── Admin ────────────────────────────────────────────────────────────────

  static Future<({List<Map<String, dynamic>> users, DocumentSnapshot? lastDoc})>
      fetchUsersPaginated({int pageSize = 50, DocumentSnapshot? lastDoc}) async {
    Query q = _db.collection('users').orderBy('nickname').limit(pageSize);
    if (lastDoc != null) q = q.startAfterDocument(lastDoc);
    final snap = await q.get();
    final users = snap.docs.map((d) => {'uid': d.id, ...d.data() as Map<String, dynamic>}).toList();
    return (users: users, lastDoc: snap.docs.isEmpty ? null : snap.docs.last);
  }

  static Future<void> setUserRole(String uid, String role) async {
    await _db.collection('users').doc(uid).update({'role': role});
  }

  static Future<void> likeComment({required String postId, required String commentId}) async {
    await _db
        .collection('communityPosts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({'likes': FieldValue.increment(1)});
  }
}
