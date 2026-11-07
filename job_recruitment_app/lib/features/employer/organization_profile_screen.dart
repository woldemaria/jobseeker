import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/location_map_modal.dart';
import 'employer_verification_screen.dart';

class OrganizationProfileScreen extends StatefulWidget {
  final ApiService apiService;

  const OrganizationProfileScreen({super.key, required this.apiService});

  @override
  State<OrganizationProfileScreen> createState() => _OrganizationProfileScreenState();
}

class _OrganizationProfileScreenState extends State<OrganizationProfileScreen> {
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _regNumController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _verificationStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _regNumController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final resp = await widget.apiService.get(ApiConstants.employerProfile);
    if (mounted) {
      if (resp.success && resp.data != null) {
        final data = resp.data;
        _nameController.text = data['organization_name'] ?? '';
        _typeController.text = data['organization_type'] ?? '';
        _regNumController.text = data['registration_number'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _websiteController.text = data['website'] ?? '';
        _addressController.text = data['address'] ?? '';
        _verificationStatus = data['verification_status'] ?? 'pending';
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final resp = await widget.apiService.put(ApiConstants.employerProfile, {
      'organization_name': _nameController.text.trim(),
      'organization_type': _typeController.text.trim(),
      'registration_number': _regNumController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'website': _websiteController.text.trim(),
      'address': _addressController.text.trim(),
    });

    if (mounted) {
      setState(() => _isSaving = false);
      if (resp.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization profile updated!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resp.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('organization_profile'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.verified_user, color: Color(0xFF0D6B4F)),
                    title: Text(loc.t('verification_status')),
                    subtitle: Text('Status: ${_verificationStatus.toUpperCase()}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmployerVerificationScreen(apiService: widget.apiService),
                        ),
                      ).then((_) => _load());
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Organization Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _typeController,
                  decoration: const InputDecoration(
                    labelText: 'Organization Type (e.g. Private, NGO, Government)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _regNumController,
                  decoration: const InputDecoration(labelText: 'Business Registration / License Number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Organization Contact Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Contact Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _websiteController,
                  decoration: const InputDecoration(labelText: 'Official Website URL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Headquarters Physical Address',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.map_outlined, color: Color(0xFF0D6B4F)),
                      tooltip: 'View on OpenStreetMap / Google Maps',
                      onPressed: () {
                        final addr = _addressController.text.trim();
                        if (addr.isNotEmpty) {
                          LocationMapModal.show(
                            context,
                            title: _nameController.text.trim().isNotEmpty
                                ? _nameController.text.trim()
                                : 'Organization Headquarters',
                            address: addr,
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(loc.t('save')),
                ),
              ],
            ),
    );
  }
}
