// lib/pages/match_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/match_provider.dart';
import '../providers/chat_provider.dart';
import '../models/match.dart';
import '../pages/chat_page.dart';

// ─── Y2K Palette ────────────────────────────────────────────────────────────
const _bgTop       = Color(0xFFFCF4F9);
const _bgBottom    = Color(0xFFF0EAFF);
const _hotPink     = Color(0xFFFFB3D9);
const _neonPurple  = Color(0xFFD9B3FF);
const _electricBlue = Color(0xFFB3D9FF);
const _accentPink  = Color(0xFFFF6FE8);
const _textPrimary = Color(0xFF1A0D26);
const _textMuted   = Color(0xFF8A7EA5);
const _dividerClr  = Color(0xFFE8DDF5);

// Fallback gradient ring colors when no photo
const _ringColors = [_hotPink, _neonPurple, _electricBlue];

class MatchPage extends StatefulWidget {
  final String uid;

  const MatchPage({super.key, required this.uid});

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchProvider>().startMatchStream();
    });
  }

  void _openChat(Match match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chatId: match.chatId ?? '',
          otherUserId: match.userId,
          otherUsername: match.username,
          otherPhotoUrl: match.photoUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = w * 0.06;
    final headerFont = (w * 0.082).clamp(24.0, 34.0);
    final sectionFont = (w * 0.032).clamp(11.0, 13.0);
    final carouselH = (h * 0.14).clamp(100.0, 120.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Consumer<MatchProvider>(
            builder: (context, matchProvider, _) {
              if (matchProvider.isLoading) {
                return const Center(child: CircularProgressIndicator(color: _hotPink));
              }

              if (matchProvider.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 48, color: _textMuted.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text("Couldn't load matches",
                            style: TextStyle(fontFamily: 'Circular', color: _textMuted, fontSize: sectionFont + 3, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(matchProvider.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Circular', color: _textMuted.withOpacity(0.7), fontSize: 12)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => matchProvider.startMatchStream(),
                          style: ElevatedButton.styleFrom(backgroundColor: _hotPink, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text("Retry", style: TextStyle(fontFamily: 'Circular', fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final allMatches = matchProvider.matches;
              final newMatches = allMatches
                  .where((m) => m.status == 'incoming' || m.status == 'pending' || m.status == 'outgoing')
                  .toList();
              final connectedMatches = allMatches
                  .where((m) => m.status == 'connected')
                  .toList();

              final newCount = newMatches.length;

              return CustomScrollView(
                slivers: [
                  // ── Header ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Matches',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontSize: headerFont,
                              fontWeight: FontWeight.w900,
                              color: _textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (newCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _dividerClr),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: _accentPink, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$newCount new',
                                    style: const TextStyle(fontFamily: 'Circular', fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ═══════════════════════════════════════════════════════
                  //  NEW MATCHES SECTION CARD
                  // ═══════════════════════════════════════════════════════
                  if (newMatches.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section header
                              Padding(
                                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28, height: 28,
                                      decoration: BoxDecoration(
                                        color: _accentPink.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.favorite_rounded, size: 14, color: _accentPink),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'New Matches',
                                      style: TextStyle(
                                        fontFamily: 'Circular',
                                        fontSize: sectionFont + 1,
                                        fontWeight: FontWeight.w800,
                                        color: _textPrimary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${newMatches.length}',
                                      style: TextStyle(
                                        fontFamily: 'Circular',
                                        fontSize: sectionFont,
                                        fontWeight: FontWeight.w700,
                                        color: _textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Carousel
                              SizedBox(
                                height: carouselH,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  itemCount: newMatches.length,
                                  itemBuilder: (ctx, i) => _NewMatchBubble(
                                    matchData: newMatches[i],
                                    ringColor: _ringColors[i % _ringColors.length],
                                    onTap: () => _openChat(newMatches[i]),
                                    qualityEmoji: newMatches[i].qualityEmoji,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Spacer between sections
                  SliverToBoxAdapter(child: SizedBox(height: newMatches.isNotEmpty ? 16 : 0)),

                  // ═══════════════════════════════════════════════════════
                  //  MESSAGES SECTION CARD
                  // ═══════════════════════════════════════════════════════
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      color: _neonPurple.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.chat_bubble_rounded, size: 14, color: _neonPurple),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Messages',
                                    style: TextStyle(
                                      fontFamily: 'Circular',
                                      fontSize: sectionFont + 1,
                                      fontWeight: FontWeight.w800,
                                      color: _textPrimary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (connectedMatches.isNotEmpty)
                                    Text(
                                      '${connectedMatches.length}',
                                      style: TextStyle(
                                        fontFamily: 'Circular',
                                        fontSize: sectionFont,
                                        fontWeight: FontWeight.w700,
                                        color: _textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Messages content
                            if (connectedMatches.isEmpty && newMatches.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.music_note_rounded, size: 48, color: _neonPurple.withOpacity(0.3)),
                                      const SizedBox(height: 12),
                                      const Text(
                                        "No matches yet 👀\nSwipe more songs!",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontFamily: 'Circular', color: _textMuted, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else if (connectedMatches.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: Text(
                                    'No conversations yet.\nAccept a match to start chatting!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'Circular', color: _textMuted.withOpacity(0.8), fontSize: 14, height: 1.5),
                                  ),
                                ),
                              )
                            else
                              ...List.generate(connectedMatches.length, (i) {
                                return Column(
                                  children: [
                                    if (i > 0)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 18),
                                        child: Divider(height: 1, color: _dividerClr.withOpacity(0.6)),
                                      ),
                                    _MessageTile(
                                      match: connectedMatches[i],
                                      onTap: () => _openChat(connectedMatches[i]),
                                    ),
                                  ],
                                );
                              }),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 20)),
                ],
              );
            },
          ),
        ),
    );
  }
}

class _NewMatchBubble extends StatelessWidget {
  final Match matchData;
  final Color ringColor;
  final VoidCallback onTap;
  final String qualityEmoji;

  const _NewMatchBubble({required this.matchData, required this.ringColor, required this.onTap, this.qualityEmoji = ''});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 68, height: 68,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ringColor, ringColor.withOpacity(0.3)],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  image: matchData.photoUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(matchData.photoUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: matchData.photoUrl.isEmpty
                    ? Icon(Icons.person_rounded, color: ringColor.withOpacity(0.5), size: 32)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              matchData.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Circular', fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary),
            ),
            if (qualityEmoji.isNotEmpty)
              Text(qualityEmoji, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final Match match;
  final VoidCallback onTap;

  const _MessageTile({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _dividerClr,
                  image: match.photoUrl.isNotEmpty
                      ? DecorationImage(image: NetworkImage(match.photoUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: match.photoUrl.isEmpty
                    ? const Icon(Icons.person_rounded, color: Colors.white, size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.username,
                      style: const TextStyle(fontFamily: 'Circular', fontSize: 16, fontWeight: FontWeight.w800, color: _textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match.sharedTasteSummary,
                      style: TextStyle(fontFamily: 'Circular', fontSize: 13, color: _textMuted.withOpacity(0.8), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    match.matchedAt != null
                        ? '${match.matchedAt!.hour}:${match.matchedAt!.minute.toString().padLeft(2, '0')}'
                        : '',
                    style: const TextStyle(fontFamily: 'Circular', fontSize: 11, color: _textMuted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (match.similarityScore > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _hotPink.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${match.similarityScore.toStringAsFixed(0)}%',
                        style: const TextStyle(fontFamily: 'Circular', fontSize: 10, fontWeight: FontWeight.w800, color: _hotPink),
                      ),
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
