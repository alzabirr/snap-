import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/local_model_service.dart';
import '../storage/hive_storage.dart';
import '../themes/app_theme.dart';
import '../widgets/ambient_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final HiveStorage _storage = HiveStorage();
  late String _profileName;
  late String _workspaceName;
  late bool _notificationsEnabled;
  late bool _cloudSyncEnabled;
  late bool _hapticFeedbackEnabled;
  bool _hasModel = false;

  @override
  void initState() {
    super.initState();
    _profileName = _storage.getSetting('profileName', 'Snap User') as String;
    _workspaceName =
        _storage.getSetting('workspaceName', 'Personal workspace') as String;
    _notificationsEnabled =
        _storage.getSetting('notificationsEnabled', true) as bool;
    _cloudSyncEnabled = _storage.getSetting('cloudSyncEnabled', false) as bool;
    _hapticFeedbackEnabled =
        _storage.getSetting('hapticFeedbackEnabled', true) as bool;
    LocalModelService.downloadProgress.addListener(_handleModelProgress);
    LocalModelService.isDownloading.addListener(_handleModelProgress);
    _loadModelState();
  }

  @override
  void dispose() {
    LocalModelService.downloadProgress.removeListener(_handleModelProgress);
    LocalModelService.isDownloading.removeListener(_handleModelProgress);
    super.dispose();
  }

  void _handleModelProgress() {
    if (mounted) setState(() {});
  }

  Future<void> _loadModelState() async {
    final hasModel = await LocalModelService.hasDownloadedModel();
    if (!mounted) return;
    setState(() => _hasModel = hasModel);
  }

  Future<void> _downloadModel() async {
    try {
      await LocalModelService.ensureDefaultModelDownloaded();
      await _loadModelState();
    } catch (_) {
      if (!mounted) return;
      _showInfoDialog(
        title: 'Download failed',
        message: 'Could not download the local model. Check internet and try again.',
      );
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    await _storage.saveSetting(key, value);
  }

  Future<void> _updateNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _saveBool('notificationsEnabled', value);
  }

  Future<void> _updateCloudSync(bool value) async {
    setState(() => _cloudSyncEnabled = value);
    await _saveBool('cloudSyncEnabled', value);
    if (!mounted) return;
    _showInfoDialog(
      title: value ? 'Cloud sync on' : 'Cloud sync off',
      message: value
          ? 'Your snaps will be marked for backup when cloud sync is connected.'
          : 'Your snaps will stay local on this device.',
    );
  }

  Future<void> _updateHapticFeedback(bool value) async {
    setState(() => _hapticFeedbackEnabled = value);
    await _saveBool('hapticFeedbackEnabled', value);
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _profileName);
    final workspaceController = TextEditingController(text: _workspaceName);

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Edit profile'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'Name',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: workspaceController,
                  placeholder: 'Workspace',
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                final name = nameController.text.trim().isEmpty
                    ? 'Snap User'
                    : nameController.text.trim();
                final workspace = workspaceController.text.trim().isEmpty
                    ? 'Personal workspace'
                    : workspaceController.text.trim();

                setState(() {
                  _profileName = name;
                  _workspaceName = workspace;
                });
                await _storage.saveSetting('profileName', name);
                await _storage.saveSetting('workspaceName', workspace);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    workspaceController.dispose();
  }

  void _showInfoDialog({required String title, required String message}) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    _showInfoDialog(
      title: 'Privacy',
      message:
          'Snap stores your profile, preferences and mind maps locally on this device.',
    );
  }

  void _showAboutDialog() {
    _showInfoDialog(
      title: 'About Snap',
      message: 'Snap 1.0.0\nA local-first mind map workspace for quick ideas.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: AmbientBackground(
        child: SafeArea(
          child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                physics: const BouncingScrollPhysics(),
                children: [
                  Row(
                    children: [
                       CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Icon(
                          CupertinoIcons.chevron_left,
                          color: textDark,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Settings',
                        style: headingStyle(
                          fontSize: 28,
                          color: textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _ProfileHeader(
                    name: _profileName,
                    workspaceName: _workspaceName,
                    onTap: _showEditProfileDialog,
                  ),
                  const SizedBox(height: 18),
                  _ModelStatusCard(
                    hasModel: _hasModel,
                    isDownloading: LocalModelService.isDownloading.value,
                    progress: LocalModelService.downloadProgress.value,
                    onDownload: _downloadModel,
                  ),
                  const SizedBox(height: 18),
                  _SettingsGroup(
                    title: 'Profile',
                    children: [
                      _ActionSetting(
                        icon: CupertinoIcons.person_crop_circle,
                        title: 'Edit profile',
                        subtitle: 'Name, photo and personal details',
                        onTap: _showEditProfileDialog,
                      ),
                      _Divider(),
                      _SwitchSetting(
                        title: 'Notifications',
                        value: _notificationsEnabled,
                        onChanged: _updateNotifications,
                      ),
                      _Divider(),
                      _SwitchSetting(
                        title: 'Cloud sync',
                        value: _cloudSyncEnabled,
                        onChanged: _updateCloudSync,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SettingsGroup(
                    title: 'App',
                    children: [
                      _SwitchSetting(
                        title: 'Dark Mode',
                        value: isDarkMode,
                        onChanged: (val) async {
                          await _storage.saveSetting('darkMode', val);
                          darkModeNotifier.value = val;
                          setState(() {});
                        },
                      ),
                      _Divider(),
                      _SwitchSetting(
                        title: 'Haptic feedback',
                        value: _hapticFeedbackEnabled,
                        onChanged: _updateHapticFeedback,
                      ),
                      _Divider(),
                      _ActionSetting(
                        icon: CupertinoIcons.lock_shield,
                        title: 'Privacy',
                        subtitle: 'Manage local data and permissions',
                        onTap: _showPrivacyDialog,
                      ),
                      _Divider(),
                      _ActionSetting(
                        icon: CupertinoIcons.info_circle,
                        title: 'About Snap',
                        subtitle: 'Version 1.0.0',
                        onTap: _showAboutDialog,
                      ),
                    ],
                  ),
                ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String workspaceName;
  final VoidCallback onTap;

  const _ProfileHeader({
    required this.name,
    required this.workspaceName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: textDark.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primary, accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                CupertinoIcons.person_fill,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: headingStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    workspaceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle(
                      color: textMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
             Icon(
              CupertinoIcons.chevron_forward,
              color: textMid,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelStatusCard extends StatelessWidget {
  final bool hasModel;
  final bool isDownloading;
  final double progress;
  final VoidCallback onDownload;

  const _ModelStatusCard({
    required this.hasModel,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0, 1) * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: textDark.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: hasModel
                      ? const Color(0xFF34D399).withValues(alpha: 0.16)
                      : primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  hasModel
                      ? CupertinoIcons.checkmark_seal_fill
                      : CupertinoIcons.cloud_download,
                  color: hasModel ? const Color(0xFF059669) : primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasModel ? 'Local AI ready' : 'Local AI model',
                      style: headingStyle(
                        fontSize: 20,
                        color: textDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasModel
                          ? 'Chat, New Snap and mind map AI are enabled.'
                          : isDownloading
                              ? 'Downloading Gemma model... $percent%'
                              : 'Starts automatically after app install.',
                      style: bodyStyle(
                        fontSize: 13,
                        color: textMid,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: progress == 0 ? null : progress.clamp(0, 1),
                backgroundColor: primary.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            ),
          ],
          if (!hasModel && !isDownloading) ...[
            const SizedBox(height: 16),
            CupertinoButton(
              color: primary,
              borderRadius: BorderRadius.circular(18),
              onPressed: onDownload,
              child: Text(
                'Download Now',
                style: bodyStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: textDark.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: bodyStyle(
              fontSize: 13,
              color: textMid,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ActionSetting extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionSetting({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle(
                    fontSize: 13,
                    color: textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
           Icon(CupertinoIcons.chevron_forward, color: textMid, size: 18),
        ],
      ),
    );
  }
}

class _LayoutSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LayoutSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<String>(
      groupValue: value,
      backgroundColor: textDark.withValues(alpha: 0.06),
      thumbColor: Colors.white,
      children: const {
        'radial': Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text('Radial'),
        ),
        'tree': Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text('Tree'),
        ),
        'horizontal': Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text('Side'),
        ),
      },
      onValueChanged: (newValue) {
        if (newValue != null) onChanged(newValue);
      },
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: bodyStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              label,
              style: bodyStyle(color: textMid, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        CupertinoSlider(
          value: value,
          min: min,
          max: max,
          activeColor: primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSetting({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: bodyStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        CupertinoSwitch(
          value: value,
          activeTrackColor: primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String name;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.name,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.12)
              : textDark.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? primary : textDark.withValues(alpha: 0.08),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: colors.take(4).map((color) {
                return Container(
                  width: 15,
                  height: 15,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(height: 1, color: textDark.withValues(alpha: 0.07)),
    );
  }
}
