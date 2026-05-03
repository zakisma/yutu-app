import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart'; 
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  // --- CLOUDINARY UPLOAD HELPER ---
  Future<String?> _uploadImageToCloudinary(XFile image) async {
    try {
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

      if (cloudName == null || uploadPreset == null) return null;

      final imageBytes = await image.readAsBytes();
      final cloudinaryUrl = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', cloudinaryUrl)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: image.name));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return jsonDecode(responseData)['secure_url'];
      }
    } catch (e) {
      print("Upload failed: $e");
    }
    return null;
  }

  // --- EDIT PROFILE DIALOG ---
  void _showEditProfileDialog(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser!;
    final addressController = TextEditingController(text: user.address);
    
    // We store the full phone number (+420123456789) here as it updates
    String currentPhoneNumber = user.phoneNumber;
    final _formKey = GlobalKey<FormState>();
    
    XFile? selectedImage;
    bool removeExistingPhoto = false;
    bool isProcessing = false;

    // Helper to determine if a photo is currently displaying
    bool hasPhoto() {
      return selectedImage != null || (user.profileImageUrl.isNotEmpty && !removeExistingPhoto);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('edit_profile'.tr()),
              content: SingleChildScrollView(
                // --- NEW: WRAPPED IN FORM ---
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // --- PROFILE PHOTO PICKER ---
                    GestureDetector(
                      onTap: isProcessing ? null : () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setDialogState(() {
                            selectedImage = image;
                            removeExistingPhoto = false; // Reset delete flag if they pick a new one
                          });
                        }
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: selectedImage != null 
                                ? (kIsWeb ? NetworkImage(selectedImage!.path) : FileImage(File(selectedImage!.path))) as ImageProvider
                                : (!removeExistingPhoto && user.profileImageUrl.isNotEmpty ? NetworkImage(user.profileImageUrl) : null),
                            child: !hasPhoto()
                                ? const Icon(Icons.person, size: 40, color: Colors.grey)
                                : null,
                          ),
                          const CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.deepPurple,
                            child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    if (hasPhoto())
                      TextButton(
                        onPressed: isProcessing ? null : () {
                          setDialogState(() {
                            selectedImage = null;
                            removeExistingPhoto = true; // Flag to send empty string to DB
                          });
                        },
                        child:  Text('remove_photo'.tr(), style: TextStyle(color: Colors.red)),
                      )
                    else
                      const SizedBox(height: 16), // Padding if no button
                    
                    const SizedBox(height: 16),
                    
                    IntlPhoneField(
                        decoration:  InputDecoration(
                          labelText: 'phonenum'.tr(),
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        initialCountryCode: 'CZ', 
                        initialValue: user.phoneNumber,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly, 
                        ],
                        onChanged: (phone) {
                          currentPhoneNumber = phone.completeNumber;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: addressController, 
                        decoration:  InputDecoration(labelText: 'shipping_addr'.tr(), prefixIcon: Icon(Icons.location_on), border: OutlineInputBorder()), 
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(context), 
                  child:  Text('cancel'.tr(), style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: isProcessing ? null : () async {
                    // --- NEW: RUN FRONTEND FORM VALIDATION ---
                    if (!_formKey.currentState!.validate()) return;
                    
                    setDialogState(() => isProcessing = true);

                    String finalImageUrl = user.profileImageUrl;
                    if (removeExistingPhoto) {
                      finalImageUrl = '';
                    } else if (selectedImage != null) {
                      final uploadedUrl = await _uploadImageToCloudinary(selectedImage!);
                      if (uploadedUrl != null) {
                        finalImageUrl = uploadedUrl;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image upload failed.')));
                        setDialogState(() => isProcessing = false);
                        return;
                      }
                    }

                    final error = await authProvider.updateProfile(finalImageUrl, currentPhoneNumber, addressController.text.trim());

                    if (!context.mounted) return;
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(error ?? 'Profile updated successfully!'),
                      backgroundColor: error == null ? Colors.green : Colors.red,
                    ));
                  },
                  child: isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      :  Text('save_changes'.tr()),
                ),
              ],
            );
          }
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    // --- GUEST VIEW ---
    if (!authProvider.isAuthenticated || user == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('account'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)), 
          backgroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(), // Pushes the center content down slightly
              
              const Icon(Icons.account_circle, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text('browsing_as_guest'.tr(), style: const TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                child: Text('login_or_register'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              
              const Spacer(),
              
              // --- GUEST LANGUAGE SWITCHER ---
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                child: ListTile(
                  leading: const Icon(Icons.language, color: Colors.deepPurple),
                  title: Text('lang'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: DropdownButton<String>(
                    value: context.locale.languageCode, 
                    underline: const SizedBox(), 
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English 🇬🇧')),
                      DropdownMenuItem(value: 'cs', child: Text('Čeština 🇨🇿')),
                    ],
                    onChanged: (String? newLanguageCode) {
                      if (newLanguageCode != null) {
                        context.setLocale(Locale(newLanguageCode)); 
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16), 
            ],
          ),
        ),
      );
    }
    // ------------------

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title:  Text('my_account'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.deepPurple),
            onPressed: () => _showEditProfileDialog(context, authProvider),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER SECTION ---
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.deepPurple.shade100,
                    backgroundImage: user.profileImageUrl.isNotEmpty ? NetworkImage(user.profileImageUrl) : null,
                    child: user.profileImageUrl.isEmpty 
                        ? Text(user.name[0].toUpperCase(), style: const TextStyle(fontSize: 40, color: Colors.deepPurple)) 
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(user.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user.email, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- DETAILS SECTION ---
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone, color: Colors.deepPurple),
                    title:  Text('phonenum'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(user.phoneNumber.isNotEmpty ? user.phoneNumber : 'Not set'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.deepPurple),
                    title:  Text('shipping_addr'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(user.address.isNotEmpty ? user.address : 'Not set'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language, color: Colors.deepPurple),
                    title: Text('lang'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: DropdownButton<String>(
                      value: context.locale.languageCode, 
                      underline: const SizedBox(), 
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English 🇬🇧')),
                        DropdownMenuItem(value: 'cs', child: Text('Čeština 🇨🇿')),
                      ],
                      onChanged: (String? newLanguageCode) {
                        if (newLanguageCode != null) {
                          // This ONE line instantly translates the entire app!
                          context.setLocale(Locale(newLanguageCode)); 
                        }
                      },
                    ),
                  )
                ],
              ),
            ),

          
            
            const SizedBox(height: 32),
            
            // --- LOGOUT BUTTON ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                  ),
                  icon: const Icon(Icons.logout),
                  label:  Text('logout'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    authProvider.logout();
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}