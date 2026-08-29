import 'package:flutter/material.dart';

void main() {
  runApp(const DoradaMotorsApp());
}

// =====================================================
// APP
// =====================================================

class DoradaMotorsApp extends StatelessWidget {
  const DoradaMotorsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dorada Motors',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE1B329),
        ),
      ),
      home: const PrincipalPage(),
    );
  }
}

// =====================================================
// MODELO PRODUCTO
// =====================================================

class Producto {
  final String nombre;
  final String marca;
  final double precio;
  final String imagen;
  final String categoria;

  const Producto({
    required this.nombre,
    required this.marca,
    required this.precio,
    required this.imagen,
    required this.categoria,
  });
}

// =====================================================
// PÁGINA PRINCIPAL
// =====================================================

class PrincipalPage extends StatefulWidget {
  const PrincipalPage({super.key});

  @override
  State<PrincipalPage> createState() => _PrincipalPageState();
}

class _PrincipalPageState extends State<PrincipalPage> {
  int paginaActual = 0;

  String categoriaSeleccionada = 'Todos';
  String busqueda = '';

  final Set<int> favoritos = {};
  final Map<int, int> carrito = {};

  final List<Producto> productos = const [
    Producto(
      nombre: 'Kit de transmisión',
      marca: 'DTIEX',
      precio: 185.00,
      imagen: 'assets/imagenes/01_kit_transmision_dtiex.png',
      categoria: 'Motor',
    ),
    Producto(
      nombre: 'Pastillas de freno',
      marca: 'DTIEX',
      precio: 45.00,
      imagen: 'assets/imagenes/02_pastillas_freno_dtiex.png',
      categoria: 'Frenos',
    ),
    Producto(
      nombre: 'Faro LED',
      marca: 'GDM',
      precio: 95.00,
      imagen: 'assets/imagenes/03_faro_led_gdm.png',
      categoria: 'Luces',
    ),
    Producto(
      nombre: 'Llanta Motokar',
      marca: 'KIGKOL',
      precio: 210.00,
      imagen: 'assets/imagenes/04_llanta_kigkol_450_12.png',
      categoria: 'Llantas',
    ),
    Producto(
      nombre: 'Aceite 20W-50',
      marca: 'GDM',
      precio: 35.00,
      imagen: 'assets/imagenes/05_aceite_gdm_20w50.png',
      categoria: 'Aceites',
    ),
    Producto(
      nombre: 'Filtro de aire',
      marca: 'DTIEX',
      precio: 40.00,
      imagen: 'assets/imagenes/06_filtro_aire_dtiex.png',
      categoria: 'Motor',
    ),
    Producto(
      nombre: 'Amortiguadores',
      marca: 'BJR',
      precio: 165.00,
      imagen: 'assets/imagenes/07_amortiguadores_bjr.png',
      categoria: 'Suspensión',
    ),
    Producto(
      nombre: 'Batería 12V',
      marca: 'KIGKOL',
      precio: 120.00,
      imagen: 'assets/imagenes/08_bateria_kigkol_12v.png',
      categoria: 'Eléctrico',
    ),
    Producto(
      nombre: 'Carburador',
      marca: 'DTIEX',
      precio: 110.00,
      imagen: 'assets/imagenes/09_carburador_dtiex.png',
      categoria: 'Motor',
    ),
    Producto(
      nombre: 'Disco de freno',
      marca: 'GDM',
      precio: 89.00,
      imagen: 'assets/imagenes/10_disco_freno_gdm.png',
      categoria: 'Frenos',
    ),
    Producto(
      nombre: 'Bujía',
      marca: 'NGK',
      precio: 25.00,
      imagen: 'assets/imagenes/11_bujia_ngk.png',
      categoria: 'Motor',
    ),
    Producto(
      nombre: 'Cadena reforzada',
      marca: 'KIGKOL',
      precio: 75.00,
      imagen: 'assets/imagenes/12_cadena_kigkol.png',
      categoria: 'Motor',
    ),
    Producto(
      nombre: 'Espejos retrovisores',
      marca: 'GDM',
      precio: 55.00,
      imagen: 'assets/imagenes/13_espejos_gdm.png',
      categoria: 'Accesorios',
    ),
    Producto(
      nombre: 'Pastillas de freno TVS',
      marca: 'TVS',
      precio: 48.00,
      imagen: 'assets/imagenes/14_pastillas_freno_tvs.png',
      categoria: 'Frenos',
    ),
    Producto(
      nombre: 'Tapa motor Lifan',
      marca: 'LIFAN',
      precio: 85.00,
      imagen: 'assets/imagenes/15_tapa_motor_lifan.png',
      categoria: 'Motor',
    ),
    Producto(
      nombre: 'Tanque combustible',
      marca: 'KIGKOL',
      precio: 145.00,
      imagen: 'assets/imagenes/16_tanque_combustible_kigkol.png',
      categoria: 'Motor',
    ),
    Producto(
      nombre: 'CDI Racing',
      marca: 'BJR',
      precio: 68.00,
      imagen: 'assets/imagenes/17_cdi_bjr_racing.png',
      categoria: 'Eléctrico',
    ),
    Producto(
      nombre: 'Luz trasera',
      marca: 'BJR',
      precio: 70.00,
      imagen: 'assets/imagenes/18_luz_trasera_bjr.png',
      categoria: 'Luces',
    ),
    Producto(
      nombre: 'Direccionales LED',
      marca: 'GDM',
      precio: 65.00,
      imagen: 'assets/imagenes/19_direccionales_led.png',
      categoria: 'Luces',
    ),
  ];

  final List<Map<String, dynamic>> categorias = const [
    {'nombre': 'Motor', 'icono': Icons.settings},
    {'nombre': 'Frenos', 'icono': Icons.album_outlined},
    {'nombre': 'Llantas', 'icono': Icons.tire_repair},
    {'nombre': 'Luces', 'icono': Icons.lightbulb_outline},
    {'nombre': 'Aceites', 'icono': Icons.water_drop_outlined},
    {'nombre': 'Eléctrico', 'icono': Icons.bolt_outlined},
  ];

  // =====================================================
  // FAVORITOS
  // =====================================================

  void cambiarFavorito(int index) {
    setState(() {
      if (favoritos.contains(index)) {
        favoritos.remove(index);
      } else {
        favoritos.add(index);
      }
    });
  }

  // =====================================================
  // CARRITO
  // =====================================================

  void agregarCarrito(int index) {
    setState(() {
      carrito[index] = (carrito[index] ?? 0) + 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${productos[index].nombre} agregado al carrito',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  int get cantidadCarrito {
    int total = 0;

    carrito.forEach((key, cantidad) {
      total += cantidad;
    });

    return total;
  }

  double get totalCarrito {
    double total = 0;

    carrito.forEach((index, cantidad) {
      total += productos[index].precio * cantidad;
    });

    return total;
  }

  // =====================================================
  // FILTRAR PRODUCTOS
  // =====================================================

  List<int> productosFiltrados() {
    final List<int> resultado = [];

    for (int i = 0; i < productos.length; i++) {
      final producto = productos[i];

      final categoriaCorrecta =
          categoriaSeleccionada == 'Todos' ||
          producto.categoria == categoriaSeleccionada;

      final texto = busqueda.toLowerCase();

      final busquedaCorrecta =
          texto.isEmpty ||
          producto.nombre.toLowerCase().contains(texto) ||
          producto.marca.toLowerCase().contains(texto);

      if (categoriaCorrecta && busquedaCorrecta) {
        resultado.add(i);
      }
    }

    return resultado;
  }

  // =====================================================
  // DETALLE PRODUCTO
  // =====================================================

  void abrirProducto(int index) {
    final producto = productos[index];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 260,
                  child: Image.asset(
                    producto.imagen,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return const Icon(
                        Icons.image_not_supported_outlined,
                        size: 80,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        cambiarFavorito(index);
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        favoritos.contains(index)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: favoritos.contains(index)
                            ? Colors.red
                            : Colors.black,
                      ),
                    ),
                  ],
                ),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    producto.marca,
                    style: const TextStyle(
                      color: Color(0xFFD6A715),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'S/ ${producto.precio.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFD6A715),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      agregarCarrito(index);
                    },
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                    ),
                    label: const Text(
                      'Agregar al carrito',
                    ),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // CARRITO
  // =====================================================

  void abrirCarrito() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, actualizarModal) {
            return Container(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * 0.78,
              ),
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Mi carrito',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (carrito.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 70,
                                color: Colors.black26,
                              ),
                              SizedBox(height: 15),
                              Text(
                                'Tu carrito está vacío',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView(
                          children: carrito.entries.map((entry) {
                            final index = entry.key;
                            final cantidad = entry.value;
                            final producto = productos[index];

                            return Container(
                              margin:
                                  const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F7),
                                borderRadius:
                                    BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 70,
                                    height: 70,
                                    child: Image.asset(
                                      producto.imagen,
                                      fit: BoxFit.contain,
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          producto.nombre,
                                          style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'S/ ${producto.precio.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color:
                                                Color(0xFFD6A715),
                                            fontWeight:
                                                FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Text(
                                    'x$cantidad',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),

                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        carrito.remove(index);
                                      });

                                      actualizarModal(() {});
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    if (carrito.isNotEmpty) ...[
                      const Divider(),

                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            'S/ ${totalCarrito.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 23,
                              color: Color(0xFFD6A715),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      SizedBox(
                        width: double.infinity,
                        height: 53,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF111827),
                          ),
                          onPressed: () {
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Compra registrada correctamente',
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Continuar compra',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =====================================================
  // FILTROS
  // =====================================================

  void abrirFiltros() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final opciones = [
          'Todos',
          'Motor',
          'Frenos',
          'Llantas',
          'Luces',
          'Aceites',
          'Eléctrico',
          'Suspensión',
          'Accesorios',
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrar productos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 18),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: opciones.map((categoria) {
                    return ChoiceChip(
                      label: Text(categoria),
                      selected:
                          categoriaSeleccionada == categoria,
                      onSelected: (_) {
                        setState(() {
                          categoriaSeleccionada = categoria;
                          paginaActual = 1;
                        });

                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 15),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // BODY SEGÚN MENÚ
  // =====================================================

  Widget paginaSeleccionada() {
    switch (paginaActual) {
      case 1:
        return paginaProductos();

      case 2:
        return paginaFavoritos();

      case 3:
        return paginaPerfil();

      default:
        return paginaInicio();
    }
  }

  // =====================================================
  // INICIO
  // =====================================================

  Widget paginaInicio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          encabezado(),

          const SizedBox(height: 28),

          const Text(
            'Todo para tu moto\nen un solo lugar',
            style: TextStyle(
              fontSize: 29,
              height: 1.12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 9),

          const Text(
            'Repuestos de calidad para motocicletas y motokar.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),

          const SizedBox(height: 22),

          buscador(),

          const SizedBox(height: 24),

          bannerOferta(),

          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Categorías',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),

              TextButton(
                onPressed: () {
                  setState(() {
                    categoriaSeleccionada = 'Todos';
                    paginaActual = 1;
                  });
                },
                child: const Text(
                  'Ver todas',
                  style: TextStyle(
                    color: Color(0xFFD6A715),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categorias.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final categoria = categorias[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      categoriaSeleccionada =
                          categoria['nombre'];
                      paginaActual = 1;
                    });
                  },
                  child: Container(
                    width: 95,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          categoria['icono'],
                          color: const Color(0xFFD6A715),
                          size: 29,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          categoria['nombre'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Productos destacados',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),

              TextButton(
                onPressed: () {
                  setState(() {
                    categoriaSeleccionada = 'Todos';
                    paginaActual = 1;
                  });
                },
                child: const Text(
                  'Ver más',
                  style: TextStyle(
                    color: Color(0xFFD6A715),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          gridProductos(
            List.generate(
              productos.length > 4 ? 4 : productos.length,
              (index) => index,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ENCABEZADO
  // =====================================================

  Widget encabezado() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/imagenes/logo_adn_imports.png',
            width: 65,
            height: 65,
            fit: BoxFit.cover,
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DORADA MOTORS',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'ADN Import\'s • Moto y Motokar',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No tienes notificaciones nuevas',
                ),
              ),
            );
          },
          icon: const Icon(
            Icons.notifications_none_rounded,
          ),
        ),

        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: abrirCarrito,
              icon: const Icon(
                Icons.shopping_cart_outlined,
              ),
            ),

            if (cantidadCarrito > 0)
              Positioned(
                right: 3,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE1B329),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$cantidadCarrito',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // =====================================================
  // BUSCADOR
  // =====================================================

  Widget buscador() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onSubmitted: (texto) {
              setState(() {
                busqueda = texto;
                paginaActual = 1;
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar repuestos, marcas...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 58,
          height: 58,
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: const Color(0xFFE1B329),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: abrirFiltros,
            child: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // BANNER
  // =====================================================

  Widget bannerOferta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF101A36),
            Color(0xFF1E316A),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OFERTA ESPECIAL',
                  style: TextStyle(
                    color: Color(0xFFE1B329),
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Hasta 25% OFF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'En repuestos seleccionados.',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 16),

                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      categoriaSeleccionada = 'Todos';
                      paginaActual = 1;
                    });
                  },
                  child: const Text('Comprar ahora'),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.two_wheeler,
            size: 70,
            color: Color(0xFFE1B329),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // PRODUCTOS
  // =====================================================

  Widget paginaProductos() {
    final indices = productosFiltrados();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Productos',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: abrirCarrito,
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          TextField(
            onChanged: (texto) {
              setState(() {
                busqueda = texto;
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: abrirFiltros,
                icon: const Icon(Icons.tune),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),

          const SizedBox(height: 18),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                filtroChip('Todos'),
                filtroChip('Motor'),
                filtroChip('Frenos'),
                filtroChip('Llantas'),
                filtroChip('Luces'),
                filtroChip('Aceites'),
                filtroChip('Eléctrico'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (indices.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  'No encontramos productos.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                  ),
                ),
              ),
            )
          else
            gridProductos(indices),
        ],
      ),
    );
  }

  Widget filtroChip(String categoria) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(categoria),
        selected: categoriaSeleccionada == categoria,
        onSelected: (_) {
          setState(() {
            categoriaSeleccionada = categoria;
          });
        },
      ),
    );
  }

  // =====================================================
  // FAVORITOS
  // =====================================================

  Widget paginaFavoritos() {
    final indices = favoritos.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mis favoritos',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: indices.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 75,
                          color: Colors.black26,
                        ),
                        SizedBox(height: 15),
                        Text(
                          'Todavía no tienes favoritos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: gridProductos(indices),
                  ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // PERFIL
  // =====================================================

  Widget paginaPerfil() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 52,
            backgroundColor: Color(0xFF111827),
            child: Icon(
              Icons.person,
              size: 58,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 15),

          const Text(
            'Mi perfil',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 30),

          opcionPerfil(
            Icons.shopping_bag_outlined,
            'Mis pedidos',
          ),

          opcionPerfil(
            Icons.location_on_outlined,
            'Direcciones',
          ),

          opcionPerfil(
            Icons.help_outline,
            'Ayuda',
          ),

          opcionPerfil(
            Icons.settings_outlined,
            'Configuración',
          ),
        ],
      ),
    );
  }

  Widget opcionPerfil(
    IconData icono,
    String texto,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$texto seleccionado'),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icono),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // GRID PRODUCTOS
  // =====================================================

  Widget gridProductos(List<int> indices) {
    return GridView.builder(
      itemCount: indices.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.67,
      ),
      itemBuilder: (context, position) {
        final index = indices[position];
        final producto = productos[index];

        return InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: () => abrirProducto(index),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Image.asset(
                          producto.imagen,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 45,
                              ),
                            );
                          },
                        ),
                      ),

                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          onPressed: () {
                            cambiarFavorito(index);
                          },
                          icon: Icon(
                            favoritos.contains(index)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: favoritos.contains(index)
                                ? Colors.red
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  producto.marca,
                  style: const TextStyle(
                    color: Color(0xFFD6A715),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  producto.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'S/ ${producto.precio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFFD6A715),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    InkWell(
                      onTap: () => agregarCarrito(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: paginaSeleccionada(),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: paginaActual,
        indicatorColor: const Color(0xFFFFEDB0),
        onDestinationSelected: (index) {
          setState(() {
            paginaActual = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Productos',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}