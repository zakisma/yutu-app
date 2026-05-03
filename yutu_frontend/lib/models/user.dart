class User {
  final int id;
  final String name;
  final String email;
  final String profileImageUrl; 
  final String phoneNumber;     
  final String address;         

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl = '',
    this.phoneNumber = '',
    this.address = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // id: json['id'] ?? 0,
      id: json['id'] is int 
          ? json['id'] 
          : int.tryParse(json['id'].toString()) ?? 0,
      name: json['full_name'] ?? json['name'] ?? 'User', 
      email: json['email'] ?? '',
      profileImageUrl: json['profile_image_url'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': name, 
      'profile_image_url': profileImageUrl,
      'phone_number': phoneNumber,
      'address': address,
    };
  }
}