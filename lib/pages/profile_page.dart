import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/auth_provider.dart';
import '../auth/utils/auth_exception.dart';
import 'profile_setup_dialog.dart';

// ── Y2K Palette (mirrors home_page.dart) ─────────────────────────
const _y2kPink = Color(0xFFFF6FE8);
const _y2kPurple = Color(0xFFB69CFF);
const _y2kBlue = Color(0xFF7BA7FF);
const _textPrimary = Color(0xFF3A2A45);
const _textMuted = Color(0xFF8A7EA5);
const _hotPink = Color(0xFFFF2D8A);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final hPad = w * 0.06;

    return Consumer<UserProfileProvider>(
      builder: (context, profileProvider, _) {
        final profile = profileProvider.profile;

        if (profile == null) {
          return const Center(child: CircularProgressIndicator(color: _y2kPink));
        }

        final username = profile.username.isNotEmpty ? profile.username : 'No name';
        final photoUrl = profile.photoUrl;
        final email = profile.email.isNotEmpty ? profile.email : 'No email';

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════════════
              //  PROFILE HEADER CARD
              // ═══════════════════════════════════════════════════
              _glassCard(
                child: Row(
                  children: [
                    // Avatar with gradient ring
                    Container(
                      width: 72, height: 72,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_y2kPink, _y2kPurple, _y2kBlue],
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          image: photoUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(photoUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: photoUrl.isEmpty
                            ? Icon(Icons.person_rounded,
                                color: _y2kPurple.withOpacity(0.5), size: 32)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontFamily: 'Circular',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _textMuted.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _openEditDialog(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _y2kPink.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: _y2kPink, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ═══════════════════════════════════════════════════
              //  LISTEN PROFILE CARD
              // ═══════════════════════════════════════════════════
              _glassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: _y2kPurple.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.graphic_eq_rounded,
                              size: 14, color: _y2kPurple),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Listen Profile',
                          style: TextStyle(
                            fontFamily: 'Circular',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (profile.genres.isNotEmpty || profile.topArtists.isNotEmpty || profile.moodHistogram.isNotEmpty) ...[
                      // Summary Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth = (constraints.maxWidth - 12) / 2;
                          
                          // Get favorite mood
                          String faveMood = 'Unknown';
                          if (profile.moodHistogram.isNotEmpty) {
                            final sortedMoods = profile.moodHistogram.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value));
                            faveMood = sortedMoods.first.key;
                          }

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _infoSlot('Top Genre', profile.genres.isNotEmpty ? profile.genres.first : 'N/A', Icons.graphic_eq, _y2kPink, itemWidth),
                              _infoSlot('Fave Mood', faveMood, Icons.auto_awesome, _y2kPurple, itemWidth),
                              if (profile.topArtists.isNotEmpty)
                                _infoSlot('Top Artist', profile.topArtists.first, Icons.person_pin, _y2kBlue, itemWidth),
                            ],
                          );
                        }
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "No listen data yet — start swiping! 🎵",
                          style: TextStyle(
                            fontFamily: 'Circular',
                            fontSize: 14,
                            color: _textMuted.withOpacity(0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ═══════════════════════════════════════════════════
              //  ACCOUNT ACTIONS CARD
              // ═══════════════════════════════════════════════════
              _glassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: _y2kBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.settings_rounded,
                              size: 14, color: _y2kBlue),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Account',
                          style: TextStyle(
                            fontFamily: 'Circular',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _actionTile(
                      icon: Icons.edit_rounded,
                      label: 'Edit Profile',
                      color: _y2kPurple,
                      onTap: () => _openEditDialog(context),
                    ),
                    Divider(height: 1, color: Colors.white.withOpacity(0.4)),
                    _actionTile(
                      icon: Icons.delete_forever_rounded,
                      label: 'Delete Account',
                      color: _hotPink,
                      onTap: () => _showDeleteAccountDialog(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  // ── Frosted glass card ────────────────────────────────────────
  static Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      child: child,
    );
  }

  // ── Section label ─────────────────────────────────────────────
  static Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Circular',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _textMuted.withOpacity(0.6),
        letterSpacing: 1.0,
      ),
    );
  }

  // ── Taste chip ────────────────────────────────────────────────
  static Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Circular',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ── Info Slot (Summarized stats) ──────────────────────────────
  Widget _infoSlot(String label, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _capitalize(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Circular',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);


  // ── Action tile ───────────────────────────────────────────────
  static Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Circular',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  color: color.withOpacity(0.4), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context) async {
    await showDialog(
        context: context,
        builder: (_) => const ProfileSetupDialog());
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _DeleteAccountDialog(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  DELETE ACCOUNT DIALOG — Y2K themed
// ══════════════════════════════════════════════════════════════════
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isEmailUser = auth.currentUser?.providerData
            .any((p) => p.providerId == 'password') ??
        false;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      backgroundColor: const Color(0xFFFFF0F8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Delete Account?",
          style: TextStyle(
              fontFamily: 'Circular',
              color: _textPrimary,
              fontWeight: FontWeight.w900)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "This action is irreversible. All your matches, chat history, and taste profile data will be permanently deleted.",
            style: TextStyle(
                fontFamily: 'Circular',
                color: _textMuted.withOpacity(0.8),
                fontSize: 13,
                height: 1.5),
          ),
          if (isEmailUser) ...[
            const SizedBox(height: 20),
            const Text(
              "Enter your password to confirm:",
              style: TextStyle(
                  fontFamily: 'Circular',
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              style: const TextStyle(
                  fontFamily: 'Circular', color: _textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.6),
                hintText: "Password",
                hintStyle:
                    TextStyle(fontFamily: 'Circular', color: _textMuted.withOpacity(0.4)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(
                    fontFamily: 'Circular',
                    color: _hotPink,
                    fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text("Cancel",
              style: TextStyle(
                  fontFamily: 'Circular',
                  color: _textMuted.withOpacity(0.7))),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _handleDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: _hotPink,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text("Delete permanently",
                  style: TextStyle(fontFamily: 'Circular')),
        ),
      ],
    );
  }

  Future<void> _handleDelete() async {
    final auth = context.read<AuthProvider>();
    final isEmailUser = auth.currentUser?.providerData
            .any((p) => p.providerId == 'password') ??
        false;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (isEmailUser) {
        final pwd = _passwordCtrl.text.trim();
        if (pwd.isEmpty) {
          setState(() {
            _loading = false;
            _error = "Password is required";
          });
          return;
        }
        await auth.reauthenticateWithPassword(pwd);
      }

      await auth.deleteAccount();
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "An unexpected error occurred";
        });
      }
    }
  }
}