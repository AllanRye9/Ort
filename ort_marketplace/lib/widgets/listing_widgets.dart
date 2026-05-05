import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

/// Displays a listing's unique tracking code as a tappable chip.
/// Tapping it copies the code to the clipboard.
class ListingCodeBadge extends StatelessWidget {
  const ListingCodeBadge({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Listing code $code copied'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_outlined,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            'Listing Code: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.copy_outlined, size: 12, color: Colors.grey[500]),
        ],
      ),
    );
  }
}

/// A compact card showing the profile of the agent/company/organisation that
/// created a listing. Reusable across properties, mfg and agric detail screens.
class ListingOwnerCard extends StatelessWidget {
  const ListingOwnerCard({super.key, required this.owner, this.onTap});

  final AgentProfileModel owner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final roleLabel = _roleLabel(owner.role);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: cs.primaryContainer,
            backgroundImage: owner.avatarUrl != null
                ? CachedNetworkImageProvider(owner.avatarUrl!)
                : null,
            child: owner.avatarUrl == null
                ? Text(
                    _initials(owner.firstName, owner.lastName),
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Name + role + uid
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${owner.firstName} ${owner.lastName}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (owner.agencyName != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          owner.agencyName!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (owner.userUid != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${owner.userUid}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
        ),
      ),
    );
  }

  static String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty ? last[0].toUpperCase() : '';
    return '$f$l';
  }

  static String _roleLabel(String role) {
    switch (role) {
      case 'agent':
        return 'Agent';
      case 'company':
        return 'Company';
      case 'organization':
        return 'Organisation';
      case 'admin':
        return 'Admin';
      default:
        return 'Seller';
    }
  }
}
