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
      codigo: json['codigo']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? 'GENERAL',
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
      tendencia: json['tendencia']?.toString() ?? 'ESTABLE',
      riesgoQuiebre: json['riesgo_quiebre']?.toString() ?? 'BAJO',
      periodoCritico: (json['semana_critica'] ??
              json['dia_critico'] ??
              json['mes_critico'] ??
              'Sin quiebre previsto')
          .toString(),
      sugerenciaReordenUnidades:
          (json['sugerencia_reorden_unidades'] as num?)?.toInt() ?? 0,
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
      periodo: json['periodo']?.toString() ?? '',
      ventasReales: (json['ventas_reales'] as num?)?.toInt(),
      ventasPredichas: (json['ventas_predichas'] as num?)?.toInt() ?? 0,
      limiteInferior: (json['limite_inferior'] as num?)?.toInt() ?? 0,
      limiteSuperior: (json['limite_superior'] as num?)?.toInt() ?? 0,
    );
  }
}

class ModeloMetadatos {
  final String nombreModelo;
  final double alfa;
  final double beta;
  final double phi;
  final double rmse;
  final double wape;
  final int periodosUsados;
  final double nivelConfianza;
  final String fuente;

  ModeloMetadatos({
    required this.nombreModelo,
    required this.alfa,
    required this.beta,
    required this.phi,
    required this.rmse,
    required this.wape,
    required this.periodosUsados,
    required this.nivelConfianza,
    required this.fuente,
  });

  factory ModeloMetadatos.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return ModeloMetadatos(
        nombreModelo: 'Suavizado Exponencial Doble (Holt Amortiguado)',
        alfa: 0.3,
        beta: 0.2,
        phi: 0.9,
        rmse: 4.5,
        wape: 0.12,
        periodosUsados: 12,
        nivelConfianza: 0.95,
        fuente: 'Histórico de Facturación FarmaSIS',
      );
    }
    return ModeloMetadatos(
      nombreModelo: json['modelo']?.toString() ??
          'Suavizado Exponencial Doble (Holt Amortiguado)',
      alfa: (json['alfa'] as num?)?.toDouble() ?? 0.3,
      beta: (json['beta'] as num?)?.toDouble() ?? 0.2,
      phi: (json['phi'] as num?)?.toDouble() ?? 0.9,
      rmse: (json['rmse'] as num?)?.toDouble() ?? 0.0,
      wape: (json['wape'] as num?)?.toDouble() ?? 0.0,
      periodosUsados: (json['periodos_usados'] as num?)?.toInt() ?? 0,
      nivelConfianza: (json['nivel_confianza'] as num?)?.toDouble() ?? 0.95,
      fuente: json['fuente']?.toString() ?? 'Base de Datos FarmaSIS',
    );
  }
}

class ContratoPrediccionResponse {
  final String status;
  final String mensaje;
  final ProductoInfo producto;
  final String temporalidad;
  final ResumenPrediccion resumen;
  final List<PuntoPrediccion> serieDatos;
  final ModeloMetadatos modelo;

  ContratoPrediccionResponse({
    required this.status,
    this.mensaje = '',
    required this.producto,
    required this.temporalidad,
    required this.resumen,
    required this.serieDatos,
    required this.modelo,
  });

  factory ContratoPrediccionResponse.fromJson(Map<String, dynamic> json) {
    return ContratoPrediccionResponse(
      status: json['status']?.toString() ?? 'OK',
      mensaje: json['mensaje']?.toString() ?? '',
      producto: ProductoInfo.fromJson(
          (json['producto'] as Map<String, dynamic>?) ?? {}),
      temporalidad: json['temporalidad']?.toString() ?? 'SEMANAL',
      resumen: ResumenPrediccion.fromJson(
          (json['resumen'] as Map<String, dynamic>?) ?? {}),
      serieDatos: (json['serie_datos'] as List<dynamic>?)
              ?.map((item) =>
                  PuntoPrediccion.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      modelo: ModeloMetadatos.fromJson(
          json['modelo'] as Map<String, dynamic>?),
    );
  }
}
