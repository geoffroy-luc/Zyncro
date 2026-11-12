part of 'home_settings_screen.dart';

/// Sections de la page (espace, invitation, couleur, membres) : déplacement pur du build.
mixin _HomeSettingsScreenSections
    on
        _HomeSettingsScreenStateBase,
        _HomeSettingsGroupInfo,
        _HomeSettingsMembership {
  @override
  Widget _buildSpaceSection(
    Group group,
    TabSettings settings,
    Color primary,
    bool isOwner,
    String? photoUrl,
    String emoji,
  ) {
    return HomeSettingsSection(
      title: context.l10n.dashboardEspace,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Emoji / photo — tappable uniquement pour le propriétaire
              GestureDetector(
                onTap: isOwner
                    ? () => _showIconPicker(settings, group.emoji ?? '')
                    : null,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _loadingPhoto
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : photoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            photoUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        )
                      : Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (group.description != null)
                      Text(
                        group.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    Text(
                      context.l10n.commonMemberCount(group.memberIds.length),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                IconButton(
                  onPressed: () =>
                      _editGroupInfo(group.id, group.name, group.description),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: context.colors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildInviteSection(Group group, Color primary) {
    return HomeSettingsSection(
      title: "Code d'invitation",
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.dashboardPartageLeLienOuLe,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (group.inviteCode == null)
                ElevatedButton.icon(
                  onPressed: _generating ? null : () => _generateCode(group.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: _generating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.vpn_key_outlined, size: 18),
                  label: Text(context.l10n.dashboardGenererUnCode),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          group.inviteCode!,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                            color: primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: () {
                        unawaited(
                          Clipboard.setData(
                            ClipboardData(text: group.inviteCode!),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.dashboardCodeCopie),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      style: IconButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => shareInviteLink(
                      code: group.inviteCode!,
                      groupName: group.name,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(
                      context.l10n.dashboardPartagerLeLienDInvitation,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _generating
                        ? null
                        : () => _confirmRegenerate(group.id),
                    icon: _generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(context.l10n.dashboardRegenererLeLien2),
                    style: TextButton.styleFrom(foregroundColor: primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildThemeColorSection(TabSettings settings) {
    return HomeSettingsSection(
      title: context.l10n.dashboardCouleurDuTheme,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ColorPickerRow(
            selected: settings.homeThemeColor,
            extraColors: settings.customColors,
            hiddenBaseColors: settings.hiddenBaseColors,
            onSelect: (hex) => _updateTabSettings(
              settings,
              settings.copyWith(homeThemeColor: hex),
            ),
            onAddColor: (hex) => _updateTabSettings(
              settings,
              settings.copyWith(customColors: [...settings.customColors, hex]),
            ),
            onDeleteColor: (hex) =>
                _updateTabSettings(settings, settings.withColorRemoved(hex)),
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildMembersSection(
    Group group,
    AsyncValue<List<GroupMember>> membersAsync,
    AppUser? currentUser,
    Color primary,
    bool isOwner,
    String? photoUrl,
  ) {
    return HomeSettingsSection(
      title: context.l10n.dashboardMembres,
      child: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(context.l10n.dashboardErreur(e)),
        data: (members) => Card(
          child: Column(
            children: members.map((member) {
              final isCurrentUser = member.uid == currentUser?.uid;
              return ListTile(
                leading: UserAvatar(
                  photoUrl: member.photoUrl,
                  showPhoto: member.showProfilePhoto,
                  displayName: member.displayName,
                  color: avatarColorForUid(member.uid),
                ),
                title: Text(
                  member.displayName + (isCurrentUser ? ' (moi)' : ''),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  member.isOwner ? 'Propriétaire' : 'Membre',
                  style: TextStyle(
                    fontSize: 12,
                    color: member.isOwner
                        ? primary
                        : context.colors.textSecondary,
                  ),
                ),
                trailing: isCurrentUser
                    ? IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: context.colors.textSecondary,
                        ),
                        tooltip: context.l10n.dashboardChangerMonPseudo,
                        onPressed: () =>
                            _editMyPseudo(group.id, member.displayName),
                      )
                    : isOwner && !member.isOwner
                    ? PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: context.colors.textSecondary,
                          size: 20,
                        ),
                        onSelected: (action) {
                          if (action == 'transfer') {
                            unawaited(_confirmTransferOwnership(member));
                          } else if (action == 'remove') {
                            unawaited(_confirmRemove(member));
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'transfer',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.workspace_premium_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(context.l10n.dashboardNommerProprietaire),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_remove_outlined,
                                  size: 18,
                                  color: context.colors.error,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  context.l10n.dashboardRetirerDuGroupe2,
                                  style: TextStyle(color: context.colors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : null,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
