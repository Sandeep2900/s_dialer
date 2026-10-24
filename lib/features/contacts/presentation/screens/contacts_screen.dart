import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/services/telephony_service.dart';
import '../../../../core/widgets/alphabet_scrubber.dart';
import '../../../../core/widgets/one_ui_header.dart';
import '../../../../core/widgets/permission_banner.dart';
import '../../../../core/widgets/swipe_to_call_tile.dart';
import '../../../call/presentation/providers/call_provider.dart';
import '../providers/contacts_provider.dart';

/// Samsung One UI Contacts Tab Screen with fast alphabet scrubber & swipe-to-call
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _stopSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    ref.read(contactsProvider.notifier).search('');
    setState(() {
      _isSearching = false;
    });
  }

  void _scrollToLetter(String targetLetter) {
    if (!_scrollController.hasClients) return;

    double offset = 70.0; // Collapsed header
    final state = ref.read(contactsProvider);
    if (state.favorites.isNotEmpty) {
      offset += 128.0; // Favorites section
    }

    for (final letter in state.availableLetters) {
      if (letter == targetLetter) {
        break;
      }
      final count = state.groupedSections[letter]?.length ?? 0;
      offset += 40.0 + (count * 70.0); // section header + contact items
    }

    final maxScroll = _scrollController.position.hasContentDimensions
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final target = maxScroll > 0 ? offset.clamp(0.0, maxScroll) : 0.0;

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsState = ref.watch(contactsProvider);
    final contactsNotifier = ref.read(contactsProvider.notifier);
    final telephony = ref.read(telephonyServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalCount = contactsState.allContacts.length;

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSearching) {
          _stopSearch();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => contactsNotifier.loadContacts(forceRefresh: true),
              color: AppColors.primaryBlue,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Header (Search AppBar or Collapsible OneUiHeader)
                  if (_isSearching)
                    SliverAppBar(
                      pinned: true,
                      floating: false,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      leadingWidth: 44,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                        tooltip: 'Close search',
                        onPressed: _stopSearch,
                      ),
                      titleSpacing: 0,
                      title: Container(
                        height: 36,
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF202329) : const Color(0xFFEFF1F5),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.07),
                            width: 0.7,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, size: 18, color: AppColors.primaryBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                cursorHeight: 16,
                                cursorWidth: 1.8,
                                cursorColor: AppColors.primaryBlue,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search contacts...',
                                  hintStyle: TextStyle(
                                    fontSize: 13.5,
                                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 7),
                                ),
                                onChanged: (query) {
                                  contactsNotifier.search(query);
                                },
                              ),
                            ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (context, value, _) {
                                if (value.text.isEmpty) return const SizedBox.shrink();
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _searchController.clear();
                                    contactsNotifier.search('');
                                  },
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.15)
                                          : Colors.black.withValues(alpha: 0.12),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 12,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    OneUiHeader(
                      title: 'Contacts',
                      subtitle: '$totalCount contacts',
                      showSearchAction: true,
                      onSearchTap: _startSearch,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'Add contact',
                          onPressed: () => context.push('/contacts/edit'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: 'Settings',
                          onPressed: () => context.push('/settings'),
                        ),
                      ],
                    ),

                  // ================= SEARCH MODE CONTENT =================
                  if (_isSearching) ...[
                    if (_searchController.text.trim().isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_rounded,
                                size: 64,
                                color: isDark ? Colors.white24 : Colors.black12,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Search contacts',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Search by name, phone number, or company',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (contactsState.searchResults.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          child: Text(
                            '${contactsState.searchResults.length} contacts found',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final contact = contactsState.searchResults[index];
                              final isFirst = index == 0;
                              final isLast = index == contactsState.searchResults.length - 1;

                              return Container(
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                  borderRadius: BorderRadius.vertical(
                                    top: isFirst ? const Radius.circular(AppDimensions.radiusL) : Radius.zero,
                                    bottom: isLast ? const Radius.circular(AppDimensions.radiusL) : Radius.zero,
                                  ),
                                  border: Border(
                                    left: BorderSide(
                                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      width: 0.8,
                                    ),
                                    right: BorderSide(
                                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      width: 0.8,
                                    ),
                                    top: isFirst
                                        ? BorderSide(
                                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                            width: 0.8,
                                          )
                                        : BorderSide.none,
                                    bottom: isLast
                                        ? BorderSide(
                                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                            width: 0.8,
                                          )
                                        : BorderSide(
                                            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                                            width: 0.6,
                                          ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.vertical(
                                    top: isFirst ? const Radius.circular(AppDimensions.radiusL) : Radius.zero,
                                    bottom: isLast ? const Radius.circular(AppDimensions.radiusL) : Radius.zero,
                                  ),
                                  child: SwipeToCallTile(
                                    backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                                    onSwipeRight: () async {
                                      final success = await ref.read(callProvider.notifier).startOutgoingCall(
                                        number: contact.primaryNumber,
                                        name: contact.displayName,
                                      );
                                      if (success && context.mounted) {
                                        context.push('/in_call', extra: {
                                          'number': contact.primaryNumber,
                                          'name': contact.displayName,
                                        });
                                      }
                                    },
                                    onSwipeLeft: () => telephony.sendSms(contact.primaryNumber),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                                      leading: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              contact.avatarColor.withValues(alpha: 0.95),
                                              contact.avatarColor.withValues(alpha: 0.72),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: contact.avatarColor.withValues(alpha: 0.28),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          contact.initials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        contact.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        contact.primaryNumber.isNotEmpty
                                            ? contact.primaryNumber
                                            : (contact.emails.isNotEmpty ? contact.emails.first.address : ''),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.call_rounded,
                                          color: AppColors.primaryBlue,
                                          size: 20,
                                        ),
                                        tooltip: 'Call',
                                        onPressed: () async {
                                          final success = await ref.read(callProvider.notifier).startOutgoingCall(
                                            number: contact.primaryNumber,
                                            name: contact.displayName,
                                          );
                                          if (success && context.mounted) {
                                            context.push('/in_call', extra: {
                                              'number': contact.primaryNumber,
                                              'name': contact.displayName,
                                            });
                                          }
                                        },
                                      ),
                                      onTap: () => context.push('/contacts/detail', extra: contact),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: contactsState.searchResults.length,
                          ),
                        ),
                      ),
                    ] else
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                size: 56,
                                color: isDark ? Colors.white38 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No contacts found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No results matching "${_searchController.text}"',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: () {
                                  context.push('/contacts/edit', extra: _searchController.text);
                                },
                                icon: const Icon(Icons.person_add_rounded, size: 18),
                                label: const Text('Add as new contact'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],

                  // ================= NORMAL MODE CONTENT =================
                  if (!_isSearching) ...[
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PermissionBanner(
                            title: 'Contacts permission required',
                            message: 'Grant access to view, edit, and sync your contacts.',
                          ),
                          // Favorites Section
                          if (contactsState.favorites.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB800)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'FAVORITES',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${contactsState.favorites.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 96,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(left: 16, right: 22),
                                itemCount: contactsState.favorites.length,
                                itemBuilder: (context, index) {
                                  final fav = contactsState.favorites[index];
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => context.push('/contacts/detail', extra: fav),
                                    child: Container(
                                      width: 74,
                                      margin: const EdgeInsets.only(right: 10),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  fav.avatarColor.withValues(alpha: 0.95),
                                                  fav.avatarColor.withValues(alpha: 0.72),
                                                ],
                                              ),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.white.withValues(alpha: 0.15)
                                                    : Colors.black.withValues(alpha: 0.08),
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: fav.avatarColor.withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              fav.initials,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            fav.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Alphabetically Grouped Sections
                    ...contactsState.availableLetters.map((letter) {
                      final sectionContacts = contactsState.groupedSections[letter] ?? [];

                      return SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                              child: Text(
                                letter,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryBlue,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            // Modern Card Container with symmetric margins (16 left, 22 right to clear 16px scrubber)
                            Container(
                              margin: const EdgeInsets.only(left: 16, right: 22),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: sectionContacts.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    indent: 68,
                                    endIndent: 14,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.05),
                                  ),
                                  itemBuilder: (context, index) {
                                    final contact = sectionContacts[index];
                                    return SwipeToCallTile(
                                      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                                      onSwipeRight: () async {
                                        final success = await ref.read(callProvider.notifier).startOutgoingCall(
                                          number: contact.primaryNumber,
                                          name: contact.displayName,
                                        );
                                        if (success && context.mounted) {
                                          context.push('/in_call', extra: {
                                            'number': contact.primaryNumber,
                                            'name': contact.displayName,
                                          });
                                        }
                                      },
                                      onSwipeLeft: () => telephony.sendSms(contact.primaryNumber),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                        leading: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                contact.avatarColor.withValues(alpha: 0.95),
                                                contact.avatarColor.withValues(alpha: 0.72),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: contact.avatarColor.withValues(alpha: 0.28),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            contact.initials,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          contact.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        subtitle: Text(
                                          contact.primaryNumber,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(
                                            contact.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                                            color: contact.isFavorite ? const Color(0xFFFFB800) : (isDark ? Colors.white24 : Colors.black26),
                                            size: 21,
                                          ),
                                          splashRadius: 20,
                                          onPressed: () => contactsNotifier.toggleFavorite(contact.id),
                                        ),
                                        onTap: () => context.push('/contacts/detail', extra: contact),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 125)),
                ],
              ),
            ),

            // Vertical Alphabet Scrubber Bar on Right Edge (Compact 16px wide inside 22px gutter)
            if (!_isSearching && contactsState.availableLetters.isNotEmpty)
              Positioned(
                right: 2,
                top: 110,
                bottom: 95,
                child: AlphabetScrubber(
                  availableLetters: contactsState.availableLetters,
                  onLetterSelected: _scrollToLetter,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
