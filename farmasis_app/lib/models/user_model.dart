class UserModel {
  final String id;
  final String username;
  final String nombre;
  final String apellido;
  final String email;
  final String rol;
  final String? fotoPerfil;
  final bool activo;

  UserModel({
    required this.id,
    required this.username,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.rol,
    this.fotoPerfil,
    required this.activo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      email: json['email'] ?? '',
      rol: json['rol'] ?? 'EMPLEADO',
      fotoPerfil: json['fotoPerfil'],
      activo: json['activo'] ?? true,
    );
  }
}
