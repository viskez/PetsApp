import 'package:flutter/material.dart';

import '../models/message_stats_store.dart';
import '../models/session.dart';

class ChatScreen extends StatefulWidget {
  final String sellerName;
  final String sellerPhone;

  const ChatScreen({super.key, required this.sellerName, required this.sellerPhone});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _messages = <_Msg>[
    _Msg(text: 'Hi, is this still available?', me: true, ts: DateTime.now()),
    _Msg(text: 'Yes! Please share your requirement.', me: false, ts: DateTime.now()),
  ];

  void _send() {
    final txt = _controller.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _messages.add(_Msg(text: txt, me: true, ts: DateTime.now()));
      _controller.clear();
    });
    MessageStatsStore().incrementSent(Session.currentUser.email);
    // TODO: hook to backend / sockets if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.sellerName, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final align = m.me ? Alignment.centerRight : Alignment.centerLeft;
                final bubbleColor = m.me ? Colors.teal : Colors.grey.shade300;
                final textColor = m.me ? Colors.white : Colors.black87;
                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m.text, style: TextStyle(color: textColor)),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _send,
                    style: FilledButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(12)),
                    child: const Icon(Icons.send),
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

class _Msg {
  final String text;
  final bool me;
  final DateTime ts;
  _Msg({required this.text, required this.me, required this.ts});
}
