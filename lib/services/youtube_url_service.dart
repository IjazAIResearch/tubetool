class YouTubeUrlService {
  static String? extractVideoId(String url) {
    try {
      final Uri uri = Uri.parse(url.trim());

      // Handle youtu.be format
      if (uri.host == 'youtu.be') {
        return uri.pathSegments.first;
      }

      // Handle youtube.com formats
      if (uri.host.contains('youtube.com')) {
        // Regular watch URL
        if (uri.queryParameters.containsKey('v')) {
          return uri.queryParameters['v'];
        }

        // Shorts URL
        if (uri.pathSegments.contains('shorts')) {
          return uri.pathSegments[uri.pathSegments.indexOf('shorts') + 1];
        }

        // Embedded video
        if (uri.pathSegments.contains('embed')) {
          return uri.pathSegments[uri.pathSegments.indexOf('embed') + 1];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static String? extractChannelId(String url) {
    try {
      // If already a channel ID, return it
      if (url.trim().startsWith('UC') && url.trim().length == 24) {
        return url.trim();
      }

      final Uri uri = Uri.parse(url.trim());

      if (!uri.host.contains('youtube.com')) {
        return null;
      }

      // Direct channel ID format
      if (uri.pathSegments.contains('channel')) {
        final index = uri.pathSegments.indexOf('channel');
        if (index + 1 < uri.pathSegments.length) {
          return uri.pathSegments[index + 1];
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static String? extractUsername(String url) {
    try {
      // Handle plain username
      if (url.startsWith('@')) {
        return url;
      }

      final Uri uri = Uri.parse(url.trim());

      if (!uri.host.contains('youtube.com')) {
        return null;
      }

      // Handle @username format
      if (uri.pathSegments.isNotEmpty && uri.pathSegments[0].startsWith('@')) {
        return uri.pathSegments[0];
      }

      // Handle youtube.com/c/username format
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'c') {
        return '@${uri.pathSegments[1]}';
      }

      // Handle youtube.com/user/username format
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'user') {
        return '@${uri.pathSegments[1]}';
      }

      // Handle plain channel name/username without @ symbol
      if (url.trim().isNotEmpty && !url.contains('/')) {
        return '@${url.trim()}';
      }

      return null;
    } catch (e) {
      if (url.trim().isNotEmpty && !url.contains('/')) {
        return '@${url.trim()}';
      }
      return null;
    }
  }
}
