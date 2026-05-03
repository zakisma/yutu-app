import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auction_provider.dart';
import '../providers/auth_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class CreateAuctionScreen extends StatefulWidget {
  const CreateAuctionScreen({super.key});

  @override
  State<CreateAuctionScreen> createState() => _CreateAuctionScreenState();
}

class _CreateAuctionScreenState extends State<CreateAuctionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _buyNowPriceController = TextEditingController();

  String _selectedCategory = 'Electronics';
  int _selectedDurationDays = 7;
  final List<int> _durationOptions = [3, 5, 7, 10, 14];
  
  List<XFile> _selectedImages = []; 
  bool _isUploading = false;

  // these will be translated after, don't change, if something added, add to languages in assets too
  final List<String> _categoryValues = ['Electronics', 'Fashion', 'Collectibles', 'Home', 'Other'];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    try {
      final List<XFile> selectedImages = await _picker.pickMultiImage();
      if (selectedImages.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(selectedImages); 
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_gallery'.tr())),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_fill_fields_image'.tr())),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_invalid_price'.tr())),
      );
      return;
    }

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final endTime = DateTime.now().add(Duration(days: _selectedDurationDays)).toUtc().toIso8601String();
    final buyNowPriceInput = double.tryParse(_buyNowPriceController.text) ?? 0.0;

    if (buyNowPriceInput > 0 && buyNowPriceInput <= price) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_buy_now_too_low'.tr())),
      );
      return;
    }
  
    setState(() => _isUploading = true);

    final error = await Provider.of<AuctionProvider>(context, listen: false).createAuction(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      startingPrice: price, 
      endTime: endTime,
      buyNowPrice: buyNowPriceInput,
      images: _selectedImages,
      token: token!,
    );

    if (!mounted) return;

    setState(() => _isUploading = false);

    if (error == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auction_listed_success'.tr()), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sell_an_item'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- MULTI-IMAGE GALLERY UI ---
              if (_selectedImages.isEmpty)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('tap_to_select_photos'.tr(), style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _selectedImages.length) {
                            return GestureDetector(
                              onTap: _pickImages,
                              child: Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.add, size: 40, color: Colors.grey),
                              ),
                            );
                          }
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: kIsWeb 
                                        ? NetworkImage(_selectedImages[index].path) 
                                        : FileImage(File(_selectedImages[index].path)) as ImageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 16,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.red,
                                    child: Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${_selectedImages.length} ${'photos_selected'.tr()}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              // --- END MULTI-IMAGE UI ---

              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                maxLength: 60,
                decoration: InputDecoration(labelText: 'title_label'.tr()),
                validator: (val) => val!.isEmpty ? 'required_field'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(labelText: 'description_label'.tr()),
                maxLines: 3,
                validator: (val) => val!.isEmpty ? 'required_field'.tr() : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                value: _selectedDurationDays,
                decoration: InputDecoration(
                  labelText: 'duration_label'.tr(),
                  prefixIcon: const Icon(Icons.timer),
                ),
                items: _durationOptions.map((days) {
                  return DropdownMenuItem<int>(
                    value: days,
                    child: Text('$days ${'days_plural'.tr()}'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedDurationDays = val!),
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(labelText: 'category_input_label'.tr()),
                items: _categoryValues.map((cat) {
                  // dynamically translate the category name (e.g., 'cat_electronics')
                  return DropdownMenuItem(value: cat, child: Text('cat_${cat.toLowerCase()}'.tr()));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'starting_price_label'.tr(), 
                  suffixText: ' Kč', 
                  suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? 'required_field'.tr() : null,
              ),
              
              const SizedBox(height: 16),
              TextFormField(
                controller: _buyNowPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'buy_now_price_label'.tr(),
                  helperText: 'leave_empty_standard_auction'.tr(),
                  suffixText: ' Kč',
                  suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isUploading ? null : _submitForm,
                child: _isUploading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('list_item_btn'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}