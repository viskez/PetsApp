import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';

const _adminStorageKey = 'admin_dashboard_state_v1';

class HelpTab extends StatefulWidget {
  const HelpTab({super.key});

  @override
  State<HelpTab> createState() => _HelpTabState();
}

class _HelpTabState extends State<HelpTab> with WidgetsBindingObserver {
  List<_UserQuery> _myQueries = const [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadQueries();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 8), (_) => _loadQueries(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadQueries();
    }
  }

  Future<void> _loadQueries({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_adminStorageKey);
    List<_UserQuery> result = [];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final queries = decoded['queries'] as List?;
          final userName = Session.currentUser.name;
          if (queries != null) {
            for (final item in queries) {
              if (item is Map && (item['user'] == userName)) {
                final statusStr = '${item['status'] ?? (item['resolved'] == true ? 'resolved' : 'pending')}';
                final rawDate = item['createdAt'];
                DateTime createdAt;
                if (rawDate is String) {
                  createdAt =
                      DateTime.tryParse(rawDate) ?? DateTime.now();
                } else {
                  createdAt = DateTime.now();
                }
                result.add(_UserQuery(
                  title: '${item['title'] ?? 'Query'}',
                  detail: '${item['detail'] ?? ''}',
                  location: '${item['location'] ?? ''}',
                  channel: '${item['channel'] ?? ''}',
                  reasons: (item['reasons'] as List?)
                          ?.map((e) => '$e'.trim())
                          .where((e) => e.isNotEmpty)
                          .toList() ??
                      const [],
                  extraDetails: '${item['extraDetails'] ?? ''}',
                  createdAt: createdAt,
                  status: statusStr,
                ));
              }
            }
          }
        }
      } catch (_) {
        // ignore malformed cache
      }
    }
    if (!mounted) return;
    setState(() {
      _myQueries = result;
      _loading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'inprogress':
      case 'in_progress':
      case 'in-progress':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Icons.check_circle;
      case 'inprogress':
      case 'in_progress':
      case 'in-progress':
        return Icons.autorenew;
      case 'pending':
      default:
        return Icons.error_outline;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return 'Resolved';
      case 'inprogress':
      case 'in_progress':
      case 'in-progress':
        return 'In progress';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  String _formatDate(DateTime dt) =>
      DateFormat('dd MMM, HH:mm').format(dt);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Need help?', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text("We're here for you. Check the FAQs below or contact support."),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: (){}, icon: const Icon(Icons.support_agent), label: const Text('Contact Support')),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
            title: const Text('Submit query / complaint', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Send details to the admin team'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final submitted = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const _UserQueryFormScreen()),
              );
              if (submitted == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Your query was sent to admins')),
                );
                await _loadQueries();
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My queries',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (_loading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ))
                else if (_myQueries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(4),
                    child: Text('No queries submitted yet.'),
                  )
                else
                  ..._myQueries.map((q) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Icon(_statusIcon(q.status), color: _statusColor(q.status)),
                        title: Text(q.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${q.detail.isEmpty ? 'No details added' : q.detail}\nCreated ${_formatDate(q.createdAt)}'),
                        trailing: Text(_statusLabel(q.status),
                            style: TextStyle(
                                color: _statusColor(q.status),
                                fontWeight: FontWeight.w600)),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => _UserQueryDetailScreen(
                                    query: q,
                                    statusColor: _statusColor(q.status),
                                    statusLabel: _statusLabel(q.status),
                                    statusIcon: _statusIcon(q.status),
                                  )),
                        ),
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _Faq(title: 'How do I buy a pet?', body: 'Use the Buy tab, filter by category, open details and tap Buy or Chat.'),
        const _Faq(title: 'How do I add to wishlist?', body: 'Tap the heart on a listing or in the pet details screen.'),
        const _Faq(title: 'How do I sell my pet?', body: 'Open the Sell tab, fill the form and upload photos.'),
      ],
    );
  }
}

class _UserQuery {
  final String title;
  final String detail;
  final String location;
  final String channel;
  final List<String> reasons;
  final String extraDetails;
  final DateTime createdAt;
  final String status;
  const _UserQuery(
      {required this.title,
      required this.detail,
      required this.location,
      required this.channel,
      required this.reasons,
      required this.extraDetails,
      required this.createdAt,
      required this.status});
}

class _UserQueryDetailScreen extends StatelessWidget {
  final _UserQuery query;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;
  const _UserQueryDetailScreen(
      {required this.query,
      required this.statusColor,
      required this.statusLabel,
      required this.statusIcon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Query / Complaint')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(query.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 18)),
                ),
              ]),
              const SizedBox(height: 12),
              Text(query.detail.isEmpty ? 'No details provided' : query.detail),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Status: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(statusLabel, style: TextStyle(color: statusColor)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Created: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(DateFormat('dd MMM yyyy, HH:mm').format(query.createdAt)),
              ]),
              if (query.reasons.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Reasons:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: query.reasons
                      .map((r) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(r,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
              ],
              if (query.location.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Where:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(query.location),
              ],
              if (query.channel.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('How:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(query.channel),
              ],
              if (query.extraDetails.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Extra details:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(query.extraDetails),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  final String title; final String body;
  const _Faq({required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [Padding(padding: const EdgeInsets.fromLTRB(16,0,16,16), child: Text(body))]),
  );
}

class _UserQueryFormScreen extends StatefulWidget {
  const _UserQueryFormScreen();
  @override
  State<_UserQueryFormScreen> createState() => _UserQueryFormScreenState();
}

class _UserQueryFormScreenState extends State<_UserQueryFormScreen> {
  final _title = TextEditingController();
  final _detail = TextEditingController();
  final _location = TextEditingController();
  final _channel = TextEditingController(text: 'Help tab');
  final _reasons = TextEditingController();
  final _extraDetails = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    _location.dispose();
    _channel.dispose();
    _reasons.dispose();
    _extraDetails.dispose();
    super.dispose();
  }

  Future<void> _saveQueryToAdmin(Map<String, dynamic> query) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> state = {};
    final raw = prefs.getString(_adminStorageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          state.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    final existing = (state['queries'] as List?)?.toList() ?? <dynamic>[];
    existing.add(query);
    state['queries'] = existing;
    await prefs.setString(_adminStorageKey, jsonEncode(state));
  }

  Future<void> _handleSubmit() async {
    String? missing;
    if (_title.text.trim().isEmpty) {
      missing = 'Title';
    } else if (_detail.text.trim().isEmpty) {
      missing = 'Detail';
    } else if (_location.text.trim().isEmpty) {
      missing = 'Where it happened';
    } else if (_channel.text.trim().isEmpty) {
      missing = 'How it was reported';
    } else if (_reasons.text.trim().isEmpty) {
      missing = 'Reasons / causes';
    } else if (_extraDetails.text.trim().isEmpty) {
      missing = 'Extra details / notes';
    }
    if (missing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$missing is required')),
      );
      return;
    }
    setState(() => _saving = true);
    final user = Session.currentUser;
    final reasons = _reasons.text
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final payload = {
      'title': _title.text.trim(),
      'user': user.name,
      'detail': _detail.text.trim().isEmpty
          ? 'No details provided'
          : _detail.text.trim(),
      'location': _location.text.trim(),
      'channel': _channel.text.trim().isEmpty ? 'Help tab' : _channel.text.trim(),
      'reasons': reasons,
      'extraDetails': _extraDetails.text.trim(),
      'status': 'pending',
      'resolved': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _saveQueryToAdmin(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit query / complaint')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _detail,
            decoration: const InputDecoration(labelText: 'What happened?'),
            maxLines: 3,
          ),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
                labelText: 'Where (screen / flow)'),
          ),
          TextField(
            controller: _channel,
            decoration: const InputDecoration(
                labelText: "How you're reporting this"),
          ),
          TextField(
            controller: _reasons,
            decoration: const InputDecoration(
                labelText: 'Possible reasons (one per line)'),
            maxLines: 3,
          ),
          TextField(
            controller: _extraDetails,
            decoration:
                const InputDecoration(labelText: 'Extra details / attachments'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _handleSubmit,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_saving ? 'Sending...' : 'Send to admin'),
            ),
          ),
        ],
      ),
    );
  }
}
