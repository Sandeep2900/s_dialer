import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../data/models/contact_item.dart';
import '../../../../data/repositories/contacts_repository.dart';
import '../providers/contacts_provider.dart';

/// Samsung One UI Add / Edit Contact Screen
class ContactEditScreen extends ConsumerStatefulWidget {
  final dynamic initialData; // ContactItem or String (phone number or name)

  const ContactEditScreen({super.key, this.initialData});

  @override
  ConsumerState<ContactEditScreen> createState() => _ContactEditScreenState();
}

class _ContactEditScreenState extends ConsumerState<ContactEditScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _companyController;
  late final TextEditingController _notesController;

  String _phoneLabel = 'Mobile';
  ContactAccountType _selectedAccount = ContactAccountType.phone;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _existingId;

  static const List<String> _phoneLabels = ['Mobile', 'Work', 'Home', 'Main'];

  @override
  void initState() {
    super.initState();
    String firstName = '';
    String lastName = '';
    String phone = '';
    String email = '';
    String company = '';
    String notes = '';

    if (widget.initialData is ContactItem) {
      final c = widget.initialData as ContactItem;
      _isEditing = true;
      _existingId = c.id;
      firstName = c.firstName;
      lastName = c.lastName;
      if (c.phones.isNotEmpty) {
        phone = c.phones.first.number;
        _phoneLabel = c.phones.first.label;
      }
      if (c.emails.isNotEmpty) email = c.emails.first.address;
      company = c.company ?? '';
      notes = c.notes ?? '';
      _selectedAccount = c.accountType;
    } else if (widget.initialData is String) {
      final text = widget.initialData as String;
      // If it looks like a phone number
      if (RegExp(r'^\+?[0-9\s\-]+$').hasMatch(text)) {
        phone = text;
      } else {
        firstName = text;
      }
    }

    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
    _phoneController = TextEditingController(text: phone);
    _emailController = TextEditingController(text: email);
    _companyController = TextEditingController(text: company);
    _notesController = TextEditingController(text: notes);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _getInitials() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    } else if (first.isNotEmpty) {
      return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
    } else if (last.isNotEmpty) {
      return last.substring(0, last.length >= 2 ? 2 : 1).toUpperCase();
    } else if (_phoneController.text.trim().isNotEmpty) {
      return '#';
    }
    return '?';
  }

  Color _getAvatarColor() {
    final name = '${_firstNameController.text} ${_lastNameController.text}'.trim();
    if (name.isEmpty) return AppColors.primaryBlue;
    return AppColors.getAvatarColor(name);
  }

  Future<void> _saveContact() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final company = _companyController.text.trim();
    final notes = _notesController.text.trim();

    if (firstName.isEmpty && lastName.isEmpty && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name or phone number'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final displayName = '$firstName $lastName'.trim().isNotEmpty
          ? '$firstName $lastName'.trim()
          : phone;

      final repo = ref.read(contactsRepositoryProvider);
      final contact = ContactItem(
        id: _existingId ?? 'contact_${DateTime.now().millisecondsSinceEpoch}',
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        phones: phone.isNotEmpty ? [ContactPhone(number: phone, label: _phoneLabel, isDefault: true)] : [],
        emails: email.isNotEmpty ? [ContactEmail(address: email)] : [],
        company: company.isNotEmpty ? company : null,
        notes: notes.isNotEmpty ? notes : null,
        accountType: _selectedAccount,
      );

      if (_isEditing) {
        await repo.updateContact(contact);
      } else {
        await repo.createContact(contact);
      }

      await ref.read(contactsProvider.notifier).loadContacts(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Contact updated' : 'Contact saved'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primaryBlue,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving contact: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing ? 'Edit contact' : 'Create contact',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: FilledButton(
                onPressed: _isSaving ? null : _saveContact,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Centered One UI Avatar Preview
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: _getAvatarColor(),
                  child: Text(
                    _getInitials(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Storage Target Selector Chip (Phone / Google)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedAccount == ContactAccountType.phone
                      ? Icons.phone_android_rounded
                      : Icons.account_circle_outlined,
                  size: 20,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 12),
                Text(
                  'Saving to: ${_selectedAccount == ContactAccountType.phone ? "Phone storage" : "Google account"}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                PopupMenuButton<ContactAccountType>(
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                  onSelected: (account) => setState(() => _selectedAccount = account),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ContactAccountType.phone,
                      child: Row(
                        children: [
                          Icon(Icons.phone_android_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Phone storage'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: ContactAccountType.google,
                      child: Row(
                        children: [
                          Icon(Icons.account_circle_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Google account'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Name Section Card
          _buildCard(
            isDark: isDark,
            title: 'Name',
            children: [
              _buildInputField(
                controller: _firstNameController,
                label: 'First name',
                hint: 'e.g. John',
                icon: Icons.person_outline_rounded,
                isDark: isDark,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _buildInputField(
                controller: _lastNameController,
                label: 'Last name',
                hint: 'e.g. Doe',
                icon: Icons.person_outline_rounded,
                isDark: isDark,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Phone Section Card with Label Pills
          _buildCard(
            isDark: isDark,
            title: 'Phone',
            children: [
              _buildInputField(
                controller: _phoneController,
                label: 'Phone number',
                hint: 'e.g. +91 98765 43210',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                isDark: isDark,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              // Pill Chips for Label (Zero overflow, easy tap)
              Row(
                children: [
                  const Text('Type: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _phoneLabels.map((lbl) {
                          final isSelected = _phoneLabel.toLowerCase() == lbl.toLowerCase();
                          return GestureDetector(
                            onTap: () => setState(() => _phoneLabel = lbl),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                lbl,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Email & Organization Card
          _buildCard(
            isDark: isDark,
            title: 'Details',
            children: [
              _buildInputField(
                controller: _emailController,
                label: 'Email',
                hint: 'e.g. name@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildInputField(
                controller: _companyController,
                label: 'Company / Work',
                hint: 'e.g. Google',
                icon: Icons.business_outlined,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notes Card
          _buildCard(
            isDark: isDark,
            title: 'Notes',
            children: [
              _buildInputField(
                controller: _notesController,
                label: 'Notes',
                hint: 'Add notes about this contact',
                icon: Icons.notes_rounded,
                maxLines: 3,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildCard({
    required bool isDark,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.6,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          prefixIcon: Icon(icon, size: 20, color: AppColors.primaryBlue),
          suffixIcon: controller.text.isNotEmpty && maxLines == 1
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    controller.clear();
                    if (onChanged != null) onChanged('');
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
