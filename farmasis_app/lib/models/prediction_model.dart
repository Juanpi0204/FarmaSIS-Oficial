class ProductoInfo {
  final String codigo;
  final String nombre;
  final String categoria;
  final int stockActual;
  final int stockMinimo;

  ProductoInfo({
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.stockActual,
    required this.stockMinimo,
  });

  factory ProductoInfo.fromJson(Map<String, dynamic> json) {
    return ProductoInfo(
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
      categoria: json['categoria'] ?? '',
      stockActual: (json['stock_actual'] as num?)?.toInt() ?? 0,
      stockMinimo: (json['stock_minimo'] as num?)?.toInt() ?? 0,
    );
  }
}

class ResumenPrediccion {
  final int totalPredicho;
  final String tendencia;
  final String riesgoQuiebre;
  final String periodoCritico;
  final int sugerenciaReordenUnidades;

  ResumenPrediccion({
    required this.totalPredicho,
    required this.tendencia,
    required this.riesgoQuiebre,
    required this.periodoCritico,
    required this.sugerenciaReordenUnidades,
  });

  factory ResumenPrediccion.fromJson(Map<String, dynamic> json) {
    return ResumenPrediccion(
      totalPredicho: (json['total_predicho'] as num?)?.toInt() ?? 0,
      tendencia: json['tendencia'] ?? 'ESTABLE',
      riesgoQuiebre: json['riesgo_quiebre'] ?? 'BAJO',
      periodoCritico: json['semana_critica'] ?? json['dia_critico'] ?? json['mes_critico'] ?? 'N/A',
      sugerenciaReordenUnidades: (json['sugerencia_reorden_unidades'] as num?)?.toInt() ?? 0,
    );
  }
}

class PuntoPrediccion {
  final String periodo;
  final int? ventasReales;
  final int ventasPredichas;
  final int limiteInferior;
  final int limiteSuperior;

  PuntoPrediccion({
    required this.periodo,
    this.ventasReales,
    required this.ventasPredichas,
    required this.limiteInferior,
    required this.limiteSuperior,
  });

  factory PuntoPrediccion.fromJson(Map<String, dynamic> json) {
    return PuntoPrediccion(
      periodo: json['periodo'] ?? '',
      ventasReales: (json['ventas_reales'] as num?)?.toInt(),
      ventasPredichas: (json['ventas_predichas'] as num?)?.toInt() ?? 0,
      limiteInferior: (json['limite_inferior'] as num?)?.toInt() ?? 0,
      limiteSuperior: (json['limite_superior'] as num?)?.toInt() ?? 0,
    );
  }
}

class ContratoPrediccionResponse {
  final String status;
  final String mensaje; // Motivo cuando status != 'OK' (ej. SIN_DATOS)
  final ProductoInfo producto;
  final String temporalidad;
  final ResumenPrediccion resumen;
  final List<PuntoPrediccion> serieDatos;

  ContratoPrediccionResponse({
    required this.status,
    this.mensaje = '',
    required this.producto,
    required this.temporalidad,
    required this.resumen,
    required this.serieDatos,
  });

  factory ContratoPrediccionResponse.fromJson(Map<String, dynamic> json) {
    return ContratoPrediccionResponse(
      status: json['status'] ?? 'OK',
      mensaje: json['mensaje'] ?? '',
      producto: ProductoInfo.fromJson(json['producto'] ?? {}),
      temporalidad: json['temporalidad'] ?? 'SEMANAL',
      resumen: ResumenPrediccion.fromJson(json['resumen'] ?? {}),
      serieDatos: (json['serie_datos'] as List<dynamic>?)
              ?.map((item) => PuntoPrediccion.fromJson(item))
              .toList() ??
          [],
    );
  }
}
