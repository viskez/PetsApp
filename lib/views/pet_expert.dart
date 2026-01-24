// lib/views/pet_expert.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/call_stats_store.dart';
import '../models/message_stats_store.dart';
import '../models/plan_store.dart';
import '../models/session.dart';
import '../utils/plan_access.dart';

/// ---------------- Models ----------------
class Expert {
  final String name;
  final String role;
  final List<String> bullets;
  final String phone;
  final String whatsapp;
  final Color tint;
  const Expert({
    required this.name,
    required this.role,
    required this.bullets,
    required this.phone,
    required this.whatsapp,
    required this.tint,
  });
}

/// ---------------- Expert List Screen ----------------
class PetExpertScreen extends StatelessWidget {
  const PetExpertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final experts = <Expert>[
      const Expert(
        name: 'Dr. Deepika Ji',
        role: 'Veterinary Doctor',
        bullets: [
          'Tell the disease, get treatment',
          'Medication and care help',
        ],
        phone: '+911234567890',
        whatsapp: '+911234567890',
        tint: Color(0xFFFFE9E2),
      ),
      const Expert(
        name: 'Naresh Ji',
        role: 'Animal Trade Expert',
        bullets: [
          'Direct help in selling/buying',
          'Rate, timing and profit advice',
        ],
        phone: '+919876543210',
        whatsapp: '+919876543210',
        tint: Color(0xFFE9F6FF),
      ),
      const Expert(
        name: 'Sumitra Devi Ji',
        role: 'Animal Feeding Expert',
        bullets: [
          'What is the right bait, find out',
          'How much and what to feed',
        ],
        phone: '+911112223334',
        whatsapp: '+911112223334',
        tint: Color(0xFFFFF4E2),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0C8A7E),
        foregroundColor: Colors.white,
        title: const Text('Animal Partners', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: experts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _ExpertCard(
          expert: experts[i],
          onTalk: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PetExpertSupportScreen(expert: experts[i])),
          ),
        ),
      ),
    );
  }
}

class _ExpertCard extends StatelessWidget {
  const _ExpertCard({required this.expert, required this.onTalk});
  final Expert expert;
  final VoidCallback onTalk;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: expert.tint,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(0.05), offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(expert.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              _RoleChip(text: expert.role),
            ]),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(radius: 32, child: Icon(Icons.person, size: 28)),
        ]),
        const SizedBox(height: 12),
        ...expert.bullets.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check, size: 18, color: Colors.black54)),
                const SizedBox(width: 8),
                Expanded(child: Text(b, style: const TextStyle(fontSize: 14.5, height: 1.35))),
              ]),
            )),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C8A7E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: onTalk,
            child: const Text('Talk', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(.08)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E6B66))),
    );
  }
}

/// ---------------- Support Form + Chat/Call/WhatsApp ----------------
class PetExpertSupportScreen extends StatefulWidget {
  const PetExpertSupportScreen({super.key, required this.expert});
  final Expert expert;

  @override
  State<PetExpertSupportScreen> createState() => _PetExpertSupportScreenState();
}

class _PetExpertSupportScreenState extends State<PetExpertSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _petName = TextEditingController();
  final _breed = TextEditingController();
  final _age = TextEditingController();
  final _city = TextEditingController();
  final _symptoms = TextEditingController();
  String _species = 'Dog';
  String _gender = 'Female';
  String _duration = '1-3 days';
  String _urgency = 'Normal';
  String _preferred = 'Chat';
  final List<XFile> _photos = [];

  @override
  void dispose() {
    _petName.dispose();
    _breed.dispose();
    _age.dispose();
    _city.dispose();
    _symptoms.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null && _photos.length < 3) setState(() => _photos.add(x));
  }

  String _composeSummary() {
    return '''
Expert: ${widget.expert.name} (${widget.expert.role})
Pet: $_species • $_gender • Age: ${_age.text.isEmpty ? 'N/A' : _age.text}
Name: ${_petName.text.isEmpty ? 'N/A' : _petName.text} • Breed: ${_breed.text.isEmpty ? 'N/A' : _breed.text}
City: ${_city.text.isEmpty ? 'N/A' : _city.text} • Duration: $_duration • Urgency: $_urgency
Symptoms: ${_symptoms.text.trim().isEmpty ? 'N/A' : _symptoms.text.trim()}
(Photos: ${_photos.length})
''';
  }

  Future<void> _startCall() async {
    final allowed = await requirePlanPoints(context, PlanAction.call);
    if (!allowed) return;
    final uri = Uri.parse('tel:${widget.expert.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      await CallStatsStore().incrementCallsMade(Session.currentUser.email);
    }
  }

  Future<void> _startWhatsApp() async {
    final allowed = await requirePlanPoints(context, PlanAction.whatsapp);
    if (!allowed) return;
    final msg = Uri.encodeComponent(_composeSummary());
    final phone = _normalizeWhatsAppNumber(widget.expert.whatsapp);
    final uri = Uri.parse('https://wa.me/$phone?text=$msg');
    final schemeUri = Uri.parse('whatsapp://send?phone=$phone&text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (await canLaunchUrl(schemeUri)) {
      await launchUrl(schemeUri, mode: LaunchMode.externalApplication);
    }
  }

  void _startChat() {
    requirePlanPoints(context, PlanAction.chat).then((allowed) {
      if (!allowed) return;
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatScreen(initialText: _composeSummary())),
      );
    });
  }

  String _normalizeWhatsAppNumber(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) digits = '91$digits';
    return digits;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      switch (_preferred) {
        case 'Chat':
          _startChat();
          break;
        case 'Call':
          _startCall();
          break;
        case 'WhatsApp':
          _startWhatsApp();
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expert;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C8A7E),
        foregroundColor: Colors.white,
        title: const Text('Pet Expert Support'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            // header
            Container(
              decoration: BoxDecoration(color: const Color(0xFFE9F6FF), borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 26)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(e.role, style: const TextStyle(color: Colors.black54)),
                ])),
                const Icon(Icons.verified, color: Color(0xFF0C8A7E)),
              ]),
            ),
            const SizedBox(height: 12),

            // required fields
            const _Section('Pet Details'),
            Row(children: [
              Expanded(child: _Dropdown('Species', _species, ['Dog','Cat','Bird','Goat','Cattle','Other'], (v)=>setState(()=>_species=v!))),
              const SizedBox(width: 12),
              Expanded(child: _Dropdown('Gender', _gender, ['Female','Male','Unknown'], (v)=>setState(()=>_gender=v!))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Field(controller: _petName, label: 'Pet Name (optional)')),
              const SizedBox(width: 12),
              Expanded(child: _Field(controller: _breed, label: 'Breed (optional)')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Field(controller: _age, label: 'Age (in years)', keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _Dropdown('Problem Duration', _duration, ['< 24 hours','1-3 days','> 3 days','Chronic'], (v)=>setState(()=>_duration=v!))),
            ]),

            const SizedBox(height: 16),
            const _Section('Location & Urgency'),
            Row(children: [
              Expanded(child: _Field(controller: _city, label: 'City / Location', validator: (v)=> (v==null||v.isEmpty)?'Required':null)),
              const SizedBox(width: 12),
              Expanded(child: _Dropdown('Urgency', _urgency, ['Low','Normal','High','Emergency'], (v)=>setState(()=>_urgency=v!))),
            ]),

            const SizedBox(height: 16),
            const _Section('Symptoms (Required)'),
            _Field(
              controller: _symptoms,
              label: 'Describe symptoms...',
              maxLines: 4,
              validator: (v)=> (v==null||v.trim().isEmpty)?'Please describe the issue':null,
            ),

            const SizedBox(height: 16),
            const _Section('Photos (up to 3)'),
            Wrap(spacing: 10, runSpacing: 10, children: [
              ..._photos.map((x) => Stack(alignment: Alignment.topRight, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(x.path), width: 90, height: 90, fit: BoxFit.cover),
                    ),
                    InkWell(
                      onTap: () => setState(()=>_photos.remove(x)),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                        child: const Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    )
                  ])),
              if (_photos.length < 3)
                OutlinedButton.icon(onPressed: _pickPhoto, icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Add Photo')),
            ]),

            const SizedBox(height: 18),
            const _Section('Preferred Contact'),
            Wrap(spacing: 8, children: [
              for (final m in ['Chat','Call','WhatsApp'])
                ChoiceChip(
                  label: Text(m),
                  selected: _preferred == m,
                  onSelected: (_) => setState(()=>_preferred = m),
                ),
            ]),
          ],
        ),
      ),

      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(blurRadius: 18, color: Colors.black.withOpacity(0.12), offset: const Offset(0, -6))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: _ActionBtn(icon: Icons.chat_bubble_outline, label: 'Chat', onTap: _startChat)),
            const SizedBox(width: 12),
            Expanded(child: _ActionBtn(icon: Icons.call_outlined, label: 'Call', onTap: _startCall)),
            const SizedBox(width: 12),
           // Expanded(child: _ActionBtn(icon: Icons.whatsapp, label: 'WhatsApp', onTap: _startWhatsApp)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C8A7E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submit,
              child: const Text('Submit & Continue', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54)));
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown(this.label, this.value, this.items, this.onChanged);
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, this.maxLines = 1, this.keyboardType, this.validator});
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator ?? (v) => null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// ---------------- Simple Chat Placeholder ----------------
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialText = ''});
  final String initialText;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _messages = <String>[];

  @override
  void initState() {
    super.initState();
    if (widget.initialText.isNotEmpty) _messages.add(widget.initialText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF0C8A7E), foregroundColor: Colors.white, title: const Text('Chat with Expert')),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (_, i) => Align(
              alignment: i.isEven ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.grey.shade200 : const Color(0xFF0C8A7E).withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_messages[i]),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(children: [
            Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Type a message'))),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                final text = _controller.text.trim();
                if (text.isEmpty) return;
                setState(() => _messages.add(text));
                _controller.clear();
                MessageStatsStore()
                    .incrementSent(Session.currentUser.email);
              },
              icon: const Icon(Icons.send),
            ),
          ]),
        ),
      ]),
    );
  }
}
