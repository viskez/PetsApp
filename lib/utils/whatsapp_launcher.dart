import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

String normalizeWhatsAppNumber(String phone) {
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  digits = digits.replaceFirst(RegExp(r'^0+'), '');
  if (digits.length < 10) return '';
  if (digits.length == 10) {
    // Default to India code when users enter local 10-digit numbers.
    digits = '91$digits';
  }
  return digits;
}

Future<bool> launchWhatsAppChat(
  BuildContext context,
  String phone,
  String message,
) async {
  final digits = normalizeWhatsAppNumber(phone);
  if (digits.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp number is missing or invalid.')),
    );
    return false;
  }

  Future<bool> tryLaunch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }

  final encodedMsg = Uri.encodeComponent(message);
  final appUrl =
      Uri.parse('whatsapp://send?phone=$digits&text=$encodedMsg');
  final webUrl = Uri.parse('https://wa.me/$digits?text=$encodedMsg');

  final openedApp =
      await tryLaunch(appUrl, LaunchMode.externalNonBrowserApplication);
  if (openedApp) return true;

  final openedWeb = await tryLaunch(webUrl, LaunchMode.externalApplication);
  if (openedWeb) return true;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open WhatsApp on this device.')),
  );
  return false;
}
