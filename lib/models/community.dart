import 'package:flutter/foundation.dart';

/// A single comment on a post. Only [author] may delete it.
class Comment {
  Comment({required this.id, required this.author, required this.text});
  final String id;
  final String author;
  final String text;
}

/// A community board post (a question or note), optionally with a photo.
class Post {
  Post({
    required this.id,
    required this.author,
    required this.avatarEmoji,
    required this.title,
    this.imagePath,
    this.likes = 0,
    this.likedByMe = false,
    List<Comment>? comments,
  }) : comments = comments ?? [];

  final String id;
  final String author;
  final String avatarEmoji;
  final String title;

  /// Local file path of an attached photo, or null.
  final String? imagePath;

  int likes;
  bool likedByMe;
  final List<Comment> comments;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
}

/// In-memory community board shared across the app (demo — not persisted).
/// Seeded with a few posts + comments so the board looks alive in the demo.
class CommunityStore extends ChangeNotifier {
  CommunityStore._() {
    _seed();
  }
  static final CommunityStore instance = CommunityStore._();

  final List<Post> posts = [];
  int _counter = 0;
  String _newId() => 'c${_counter++}';

  void _seed() {
    posts.addAll([
      Post(
        id: _newId(),
        author: '민수',
        avatarEmoji: '🏋️',
        title: '스쿼트 깊이를 어떻게 고치나요? 아래로 앉을 때 뒤꿈치가 떠요.',
        likes: 12,
        comments: [
          Comment(id: _newId(), author: '서아', text: '발목 가동성부터 늘려보세요. 벽 발목 스트레칭 추천!'),
          Comment(id: _newId(), author: '코치K', text: '박스 스쿼트로 깊이 감각부터 잡아보는 게 좋아요.'),
        ],
      ),
      Post(
        id: _newId(),
        author: '서아',
        avatarEmoji: '🥗',
        title: '아침 러닝 전에 먹기 좋은 간단한 식사 뭐가 있을까요?',
        likes: 24,
        comments: [
          Comment(id: _newId(), author: '재현', text: '바나나 하나랑 물 한 잔이면 충분해요.'),
        ],
      ),
      Post(
        id: _newId(),
        author: '재현',
        avatarEmoji: '😣',
        title: '벤치프레스 후 어깨 앞쪽이 아파요. 자세 좀 봐주세요!',
        likes: 7,
        comments: [
          Comment(id: _newId(), author: '하늘', text: '견갑을 먼저 모으고 내리는지 확인해보세요.'),
          Comment(id: _newId(), author: '민수', text: '그립을 살짝 좁혀보는 것도 도움 됐어요.'),
        ],
      ),
      Post(
        id: _newId(),
        author: '하늘',
        avatarEmoji: '⚽',
        title: '주간 축구 컨디셔닝 루틴 공유해요! 다들 어떻게 하시나요?',
        likes: 31,
        comments: [],
      ),
    ]);
  }

  Post addPost({
    required String author,
    required String avatarEmoji,
    required String title,
    String? imagePath,
  }) {
    final post = Post(
      id: _newId(),
      author: author,
      avatarEmoji: avatarEmoji,
      title: title,
      imagePath: imagePath,
    );
    posts.insert(0, post);
    notifyListeners();
    return post;
  }

  /// Posts written by [author], newest first (as stored).
  List<Post> postsBy(String author) =>
      posts.where((p) => p.author == author).toList();

  /// Delete a post. Only allowed when [requester] is the post's author.
  bool deletePost(Post post, String requester) {
    if (post.author != requester) return false;
    posts.removeWhere((p) => p.id == post.id);
    notifyListeners();
    return true;
  }

  void toggleLike(Post post) {
    post.likedByMe = !post.likedByMe;
    post.likes += post.likedByMe ? 1 : -1;
    if (post.likes < 0) post.likes = 0;
    notifyListeners();
  }

  void addComment(Post post, {required String author, required String text}) {
    post.comments.add(Comment(id: _newId(), author: author, text: text.trim()));
    notifyListeners();
  }

  /// Delete a comment. Only allowed when [requester] is the comment's author.
  bool deleteComment(Post post, Comment comment, String requester) {
    if (comment.author != requester) return false;
    post.comments.removeWhere((c) => c.id == comment.id);
    notifyListeners();
    return true;
  }
}
