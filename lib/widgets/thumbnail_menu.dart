import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;

class ThumbnailMenu extends StatelessWidget {
  final String videoId;
  final String videoTitle;

  const ThumbnailMenu({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  Future<void> _downloadThumbnail(
    String quality,
    String url,
    BuildContext context,
  ) async {
    // Request appropriate permission depending on Android major version
    Permission permissionToRequest = Permission.storage;
    if (!Platform.isAndroid) {
      permissionToRequest = Permission.storage;
    } else {
      final int androidVer = await _androidApiLevel();
      if (androidVer >= 13) {
        // Android 13+ uses photos permission for saving to gallery
        permissionToRequest = Permission.photos;
      } else {
        // For Android 11 and 12 we prefer asking the storage (READ/WRITE) permission
        // first so the system shows the standard runtime popup. MANAGE_EXTERNAL_STORAGE
        // is a special permission that generally requires the user to toggle it in
        // Settings, so we avoid forcing that unless necessary.
        permissionToRequest = Permission.storage;
      }
    }

    PermissionStatus status = await permissionToRequest.status;

    // If permission isn't granted, try requesting it and show rationale when needed
    if (!status.isGranted) {
      // If we should show a rationale, show an in-app dialog with 'Allow' that
      // triggers the runtime request (so user can grant directly from the popup).
      if (await permissionToRequest.shouldShowRequestRationale) {
        final granted = await _showRationaleDialog(
          context,
          permissionToRequest,
        );
        if (!granted) {
          // user canceled from rationale dialog
          return;
        }
        status = await permissionToRequest.status;
      } else {
        // No rationale required – request permission directly
        status = await permissionToRequest.request();
      }
    }

    // If still not granted, handle permanent denial by guiding to Settings
    // if (!status.isGranted) {
    //   if (status.isPermanentlyDenied) {
    //     _showPermissionDialog(
    //       context,
    //       'Storage permission is required to download thumbnails. You can grant it in Settings.',
    //     );
    //   } else {
    //     // Temporary denial (user tapped deny) – show a small message
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(
    //         content: Text(
    //           'Storage permission is required to download thumbnails.',
    //         ),
    //       ),
    //     );
    //   }
    //   return;
    // }
    try {
      // Download image
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download thumbnail');
      }
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      final sanitizedTitle = videoTitle.replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '_',
      );
      final fileName = '${sanitizedTitle}_$quality.jpg';
      final file = File(p.join(dir!.path, fileName));
      await file.writeAsBytes(response.bodyBytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thumbnail downloaded to ${dir.path}'),
            action: SnackBarAction(
              label: 'Share',
              onPressed:
                  () => Share.shareXFiles([
                    XFile(file.path),
                  ], text: 'Thumbnail for: $videoTitle'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to download: $e')));
      }
    }
  }

  // Helper to get Android API level
  Future<int> _androidApiLevel() async {
    try {
      final version = Platform.version;
      final match = RegExp(r'Android (\d+)').firstMatch(version);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    } catch (_) {}
    return 0;
  }

  /// Show an in-app rationale dialog explaining why we need the permission.
  /// If the user taps 'Allow' this will attempt to request the permission and
  /// return true when it's granted.
  Future<bool> _showRationaleDialog(
    BuildContext context,
    Permission perm,
  ) async {
    final completer = Completer<bool>();

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Permission required'),
            content: const Text(
              'This app needs access to storage or photos to save the thumbnail you requested.\n\n'
              'Tap "Allow" to open the permission prompt and grant access.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  completer.complete(false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  // Request the permission now; this will show the system permission popup
                  final result = await perm.request();
                  completer.complete(result.isGranted);
                },
                child: const Text('Allow'),
              ),
            ],
          ),
    );

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.download),
      tooltip: 'Download Thumbnail',
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: 'maxres',
              child: _buildMenuItem('Maximum Resolution', '1920x1080'),
            ),
            PopupMenuItem(
              value: 'high',
              child: _buildMenuItem('High Quality', '480x360'),
            ),
            PopupMenuItem(
              value: 'medium',
              child: _buildMenuItem('Medium Quality', '320x180'),
            ),
            PopupMenuItem(
              value: 'default',
              child: _buildMenuItem('Standard Quality', '120x90'),
            ),
          ],
      onSelected: (quality) async {
        final url = 'https://img.youtube.com/vi/$videoId/$quality.jpg';
        await _downloadThumbnail(quality, url, context);
      },
    );
  }

  Widget _buildMenuItem(String label, String resolution) {
    return Row(
      children: [
        const Icon(Icons.image),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            Text(
              resolution,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
