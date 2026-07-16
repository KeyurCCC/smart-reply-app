// Trigger analysis reload
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:smart_reply_app/core/di/injection.dart';
import 'package:smart_reply_app/core/enums/smart_reply_mode.dart';
import 'package:smart_reply_app/features/settings/domain/repository/settings_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsRepository _settingsRepository = getIt<SettingsRepository>();
  final _apiKeyController = TextEditingController();

  SmartReplyMode? _selectedMode;
  String _relationshipType = 'friend';
  String _preferredLanguage = 'English';
  String _chatTone = 'casual';

  bool _loading = true;
  bool _obscureApiKey = true;
  bool _testingKey = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final mode = await _settingsRepository.getSmartReplyMode();
    final apiKey = await _settingsRepository.getGeminiApiKey();
    final rel = await _settingsRepository.getRelationshipType();
    final lang = await _settingsRepository.getPreferredLanguage();
    final tone = await _settingsRepository.getChatTone();
    if (!mounted) return;
    setState(() {
      _selectedMode = mode;
      _apiKeyController.text = apiKey ?? '';
      _relationshipType = rel;
      _preferredLanguage = lang;
      _chatTone = tone;
      _loading = false;
    });
  }

  Future<void> _updateMode(SmartReplyMode mode) async {
    await _settingsRepository.setSmartReplyMode(mode);
    if (!mounted) return;
    setState(() => _selectedMode = mode);
  }

  Future<void> _updateRelationship(String val) async {
    await _settingsRepository.setRelationshipType(val);
    setState(() => _relationshipType = val);
  }

  Future<void> _updateLanguage(String val) async {
    await _settingsRepository.setPreferredLanguage(val);
    setState(() => _preferredLanguage = val);
  }

  Future<void> _updateTone(String val) async {
    await _settingsRepository.setChatTone(val);
    setState(() => _chatTone = val);
  }

  Future<void> _saveApiKey() async {
    await _settingsRepository.setGeminiApiKey(_apiKeyController.text);
    if (!mounted) return;
    setState(() => _testResult = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gemini API key saved on this device')));
  }

  Future<void> _testApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _testResult = 'Enter an API key first.');
      return;
    }

    setState(() {
      _testingKey = true;
      _testResult = null;
    });

    try {
      final model = GenerativeModel(model: 'gemini-3.1-flash-lite', apiKey: apiKey);
      final response = await model.generateContent([Content.text('Reply with exactly: OK')]);
      final text = response.text?.trim() ?? '';
      if (!mounted) return;
      setState(() {
        _testResult = text.isNotEmpty ? 'API key works.' : 'API responded but returned empty text.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = 'Test failed: $e');
    } finally {
      if (mounted) setState(() => _testingKey = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Smart reply engine', style: Theme.of(context).textTheme.titleMedium),
                ),
                RadioListTile<SmartReplyMode>(
                  title: const Text('On-device (ML Kit)'),
                  subtitle: const Text('Fast, offline, private on your phone'),
                  value: SmartReplyMode.mlKit,
                  groupValue: _selectedMode,
                  onChanged: (mode) {
                    if (mode != null) _updateMode(mode);
                  },
                ),
                RadioListTile<SmartReplyMode>(
                  title: const Text('Cloud (Gemini)'),
                  subtitle: const Text(
                    'Uses Firebase Cloud Function when deployed, '
                    'or direct Gemini with API key below',
                  ),
                  value: SmartReplyMode.gemini,
                  groupValue: _selectedMode,
                  onChanged: (mode) {
                    if (mode != null) _updateMode(mode);
                  },
                ),
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Gemini API key (device only)', style: Theme.of(context).textTheme.titleMedium),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Needed until Firebase Blaze plan is enabled and '
                    'Cloud Functions are deployed. Stored only on this phone.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureApiKey,
                    decoration: InputDecoration(
                      labelText: 'Gemini API key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _obscureApiKey = !_obscureApiKey);
                        },
                        icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(onPressed: _saveApiKey, child: const Text('Save API key')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _testingKey ? null : _testApiKey,
                          child: _testingKey
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Test key'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_testResult != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Text(
                      _testResult!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _testResult == 'API key works.' ? Colors.green : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 24),
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('AI Context Metadata', style: Theme.of(context).textTheme.titleMedium),
                ),
                ListTile(
                  title: const Text('Relationship Type'),
                  subtitle: Text(_relationshipType.isNotEmpty ? (_relationshipType[0].toUpperCase() + _relationshipType.substring(1)) : 'Friend'),
                  trailing: DropdownButton<String>(
                    value: _relationshipType,
                    onChanged: (val) {
                      if (val != null) _updateRelationship(val);
                    },
                    items: const [
                      DropdownMenuItem(value: 'friend', child: Text('Friend')),
                      DropdownMenuItem(value: 'colleague', child: Text('Colleague')),
                      DropdownMenuItem(value: 'family', child: Text('Family')),
                      DropdownMenuItem(value: 'partner', child: Text('Partner')),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('Preferred Language'),
                  subtitle: Text(_preferredLanguage),
                  trailing: DropdownButton<String>(
                    value: _preferredLanguage,
                    onChanged: (val) {
                      if (val != null) _updateLanguage(val);
                    },
                    items: const [
                      DropdownMenuItem(value: 'English', child: Text('English')),
                      DropdownMenuItem(value: 'Spanish', child: Text('Spanish')),
                      DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
                      DropdownMenuItem(value: 'French', child: Text('French')),
                      DropdownMenuItem(value: 'German', child: Text('German')),
                      DropdownMenuItem(value: 'Chinese', child: Text('Chinese')),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('Chat Tone / Emotion'),
                  subtitle: Text(_chatTone.isNotEmpty ? (_chatTone[0].toUpperCase() + _chatTone.substring(1)) : 'Casual'),
                  trailing: DropdownButton<String>(
                    value: _chatTone,
                    onChanged: (val) {
                      if (val != null) _updateTone(val);
                    },
                    items: const [
                      DropdownMenuItem(value: 'casual', child: Text('Casual')),
                      DropdownMenuItem(value: 'professional', child: Text('Professional')),
                      DropdownMenuItem(value: 'enthusiastic', child: Text('Enthusiastic')),
                      DropdownMenuItem(value: 'empathetic', child: Text('Empathetic')),
                      DropdownMenuItem(value: 'humorous', child: Text('Humorous')),
                      DropdownMenuItem(value: 'flirty', child: Text('Flirty')),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
