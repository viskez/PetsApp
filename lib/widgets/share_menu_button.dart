import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum _ShareAction { link, email, facebook, twitter }

class ShareMenuButton extends StatelessWidget {
  const ShareMenuButton({
    super.key,
    required this.shareUrl,
    required this.title,
    this.text,
  });

  /// Public URL you want to share (deep link or web link)
  final String shareUrl;

  /// Title of the pet/item (used in email/Twitter text)
  final String title;

  /// Optional extra text to include in email/tweet
  final String? text;

  String get _encodedUrl => Uri.encodeComponent(shareUrl);

  Future<void> _handle(BuildContext context, _ShareAction action) async {
    switch (action) {
      case _ShareAction.link:
        await Clipboard.setData(ClipboardData(text: shareUrl));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copied to clipboard')),
        );
        break;

      case _ShareAction.email:
        final subject = Uri.encodeComponent('Check this pet: $title');
        final body = Uri.encodeComponent('${text ?? ''}\n$shareUrl');
        final uri = Uri.parse('mailto:?subject=$subject&body=$body');
        await _launch(uri.toString(), context);
        break;

      case _ShareAction.facebook:
        final url = 'https://www.facebook.com/sharer/sharer.php?u=$_encodedUrl';
        await _launch(url, context);
        break;

      case _ShareAction.twitter:
        final tweetText = Uri.encodeComponent(text ?? 'Check this pet: $title');
        final url = 'https://twitter.com/intent/tweet?url=$_encodedUrl&text=$tweetText';
        await _launch(url, context);
        break;
    }
  }

  Future<void> _launch(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open share target')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ShareAction>(
      tooltip: 'Share',
      icon: const Icon(Icons.share_outlined),
      onSelected: (a) => _handle(context, a),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ShareAction.link,
          child: Row(
            children: const [
              Icon(Icons.link, size: 18),
              SizedBox(width: 10),
              Text('Link'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _ShareAction.email,
          child: Row(
            children: const [
              Icon(Icons.email_outlined, size: 18),
              SizedBox(width: 10),
              Text('Email'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _ShareAction.facebook,
          child: Row(
            children: const [
              Icon(Icons.facebook, size: 18),
              SizedBox(width: 10),
              Text('Facebook'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _ShareAction.twitter,
          child: Row(
            children: const [
              Icon(Icons.alternate_email, size: 18), // Twitter icon alt
              SizedBox(width: 10),
              Text('Twitter'),
            ],
          ),
        ),
      ],
    );
  }
}
