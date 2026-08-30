import 'package:flutter/material.dart';

import '../data/productos_data.dart';
import '../models/producto.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'checkout_screen.dart';
import 'orders_screen.dart';

class MainShell extends StatefulWidget {
  final bool isGuest;
  final String? userName;
  final String? userEmail;
  final VoidCallback onLoginRequested;
  final VoidCallback onLogout;

  const MainShell({
    super.key,
    required this.isGuest,
    this.userName,
    this.userEmail,
    required this.onLoginRequested,
    required this.onLogout,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _page = 0;
  String _search = '';
  String _category = 'Todos';
  String _brand = 'Todas';
  String _vehicle = 'Todos';
  Set<int> _favorites = {};
  Map<int, int> _cart = {};

  final _categories = const [
    ['Motor', Icons.settings],
    ['Frenos', Icons.album_outlined],
    ['Llantas', Icons.tire_repair],
    ['Luces', Icons.lightbulb_outline],
    ['Aceites', Icons.water_drop_outlined],
    ['Eléctrico', Icons.bolt_outlined],
    ['Suspensión', Icons.swap_vert_circle_outlined],
    ['Accesorios', Icons.extension_outlined],
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    final favorites = await LocalStore.getFavorites();
    final cart = await LocalStore.getCart();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _cart = cart;
    });
  }

  Producto _productById(int id) => productosData.firstWhere((p) => p.id == id);

  Future<void> _toggleFavorite(int id) async {
    if (widget.isGuest) {
      _requireAccount('Inicia sesión para guardar productos en Favoritos.');
      return;
    }
    setState(() {
      _favorites.contains(id) ? _favorites.remove(id) : _favorites.add(id);
    });
    await LocalStore.saveFavorites(_favorites);
  }

  Future<void> _addCart(int id) async {
    final product = _productById(id);
    final current = _cart[id] ?? 0;
    if (!product.disponible) {
      _message('Este producto está agotado.');
      return;
    }
    if (current >= product.stock) {
      _message('No hay más unidades disponibles de ${product.nombre}.');
      return;
    }
    setState(() => _cart[id] = current + 1);
    await LocalStore.saveCart(_cart);
    if (mounted) _message('${product.nombre} agregado al carrito.');
  }

  Future<void> _changeQty(int id, int delta, [VoidCallback? modalRefresh]) async {
    final product = _productById(id);
    final current = _cart[id] ?? 0;
    final next = current + delta;
    if (next <= 0) {
      _cart.remove(id);
    } else if (next <= product.stock) {
      _cart[id] = next;
    } else {
      _message('Stock máximo disponible: ${product.stock}.');
      return;
    }
    setState(() {});
    modalRefresh?.call();
    await LocalStore.saveCart(_cart);
  }

  int get _cartCount => _cart.values.fold(0, (a, b) => a + b);

  double get _cartTotal {
    double total = 0;
    _cart.forEach((id, qty) => total += _productById(id).precioFinal * qty);
    return total;
  }

  List<Producto> get _filteredProducts {
    final text = _search.trim().toLowerCase();
    return productosData.where((p) {
      final searchOk = text.isEmpty ||
          p.nombre.toLowerCase().contains(text) ||
          p.marca.toLowerCase().contains(text) ||
          p.descripcion.toLowerCase().contains(text);
      final categoryOk = _category == 'Todos' || p.categoria == _category;
      final brandOk = _brand == 'Todas' || p.marca == _brand;
      final vehicleOk = _vehicle == 'Todos' || p.tipoVehiculo.contains(_vehicle);
      return searchOk && categoryOk && brandOk && vehicleOk;
    }).toList();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _requireAccount(String text) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded, size: 35, color: AppColors.goldDark),
            ),
            const SizedBox(height: 16),
            const Text('Cuenta requerida', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.45)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ahora no')),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onLoginRequested();
            },
            child: const Text('Iniciar sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _openProduct(Producto product) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) {
          final isFavorite = _favorites.contains(product.id);
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * .91),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Image.asset(product.imagen, fit: BoxFit.contain),
                            ),
                          ),
                          if (product.precioOferta != null)
                            Positioned(
                              left: 14,
                              top: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(11)),
                                child: const Text('OFERTA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.gold)),
                              ),
                            ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: IconButton.filledTonal(
                              onPressed: () async {
                                await _toggleFavorite(product.id);
                                if (mounted) refresh(() {});
                              },
                              icon: Icon(
                                isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: isFavorite ? AppColors.danger : AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(10)),
                          child: Text(product.marca, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.goldDark)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: product.disponible ? const Color(0xFFE8F7EF) : const Color(0xFFFFE9E7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            product.disponible ? 'Disponible' : 'Agotado',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: product.disponible ? AppColors.success : AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(product.nombre, style: const TextStyle(fontSize: 27, height: 1.1, fontWeight: FontWeight.w900, color: AppColors.ink)),
                    const SizedBox(height: 9),
                    Text(product.descripcion, style: const TextStyle(color: AppColors.muted, height: 1.5)),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                      child: Column(
                        children: [
                          _detailRow(Icons.two_wheeler_outlined, 'Vehículo', product.tipoVehiculo),
                          const Divider(height: 18),
                          _detailRow(Icons.build_outlined, 'Compatibilidad', product.compatibilidad),
                          const Divider(height: 18),
                          _detailRow(Icons.inventory_2_outlined, 'Stock', product.disponible ? '${product.stock} unidades' : 'Agotado'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navySoft]),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Precio', style: TextStyle(fontSize: 11, color: Colors.white60)),
                                if (product.precioOferta != null)
                                  Text(
                                    'S/ ${product.precio.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.white54, decoration: TextDecoration.lineThrough),
                                  ),
                                Text(
                                  'S/ ${product.precioFinal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.gold),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: product.disponible
                                ? () async {
                                    await _addCart(product.id);
                                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                                  }
                                : null,
                            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink),
                            icon: const Icon(Icons.add_shopping_cart_rounded),
                            label: const Text('Agregar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 18, color: AppColors.goldDark),
        ),
        const SizedBox(width: 11),
        SizedBox(width: 92, child: Padding(padding: const EdgeInsets.only(top: 7), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)))),
        Expanded(child: Padding(padding: const EdgeInsets.only(top: 7), child: Text(value, style: const TextStyle(color: AppColors.muted)))),
      ],
    );
  }

  Future<void> _openCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * .86),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
                    child: Row(
                      children: [
                        Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.shopping_bag_outlined, color: AppColors.goldDark)),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Mi carrito', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                        IconButton.filledTonal(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                  ),
                  if (_cart.isEmpty)
                    const Expanded(child: _CartEmpty())
                  else
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                        children: _cart.entries.map((entry) {
                          final p = _productById(entry.key);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 11),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 74,
                                  height: 74,
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(16)),
                                  child: Image.asset(p.imagen, fit: BoxFit.contain),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 4),
                                      Text(p.marca, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                      const SizedBox(height: 5),
                                      Text('S/ ${p.precioFinal.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _qtyButton(Icons.remove_rounded, () => _changeQty(p.id, -1, () => refresh(() {}))),
                                      SizedBox(width: 25, child: Text('${entry.value}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900))),
                                      _qtyButton(Icons.add_rounded, () => _changeQty(p.id, 1, () => refresh(() {}))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (_cart.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(child: Text('Total del carrito', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))),
                              Text('S/ ${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.goldDark)),
                            ],
                          ),
                          const SizedBox(height: 13),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                if (widget.isGuest) {
                                  _requireAccount('Inicia sesión para confirmar tu compra y guardar el pedido.');
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CheckoutScreen(
                                      cart: Map<int, int>.from(_cart),
                                      products: productosData,
                                      onCompleted: () => setState(() => _cart.clear()),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Continuar compra'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(width: 31, height: 31, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Icon(icon, size: 17)),
    );
  }

  Future<void> _openFilters() async {
    final brands = ['Todas', ...{for (final p in productosData) p.marca}];
    String tempCategory = _category;
    String tempBrand = _brand;
    String tempVehicle = _vehicle;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)))),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Icon(Icons.tune_rounded, color: AppColors.goldDark),
                      SizedBox(width: 9),
                      Text('Filtrar productos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _filterTitle('Categoría'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: ['Todos', ..._categories.map((e) => e[0] as String)].map((value) => ChoiceChip(
                      label: Text(value),
                      selected: tempCategory == value,
                      onSelected: (_) => refresh(() => tempCategory = value),
                    )).toList(),
                  ),
                  const SizedBox(height: 18),
                  _filterTitle('Marca'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: brands.map((value) => ChoiceChip(
                      label: Text(value),
                      selected: tempBrand == value,
                      onSelected: (_) => refresh(() => tempBrand = value),
                    )).toList(),
                  ),
                  const SizedBox(height: 18),
                  _filterTitle('Vehículo'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    children: ['Todos', 'Motocicleta', 'Motokar'].map((value) => ChoiceChip(
                      label: Text(value),
                      selected: tempVehicle == value,
                      onSelected: (_) => refresh(() => tempVehicle = value),
                    )).toList(),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => refresh(() {
                            tempCategory = 'Todos';
                            tempBrand = 'Todas';
                            tempVehicle = 'Todos';
                          }),
                          child: const Text('Limpiar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _category = tempCategory;
                              _brand = tempBrand;
                              _vehicle = tempVehicle;
                              _page = 1;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Aplicar filtros'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterTitle(String text) => Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.ink));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _selectedPage()),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .08), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: NavigationBar(
          selectedIndex: _page,
          onDestinationSelected: (index) => setState(() => _page = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Productos'),
            NavigationDestination(icon: Icon(Icons.favorite_border_rounded), selectedIcon: Icon(Icons.favorite_rounded), label: 'Favoritos'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _selectedPage() {
    switch (_page) {
      case 1:
        return _productsPage();
      case 2:
        return _favoritesPage();
      case 3:
        return _profilePage();
      default:
        return _homePage();
    }
  }

  Widget _homePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 20),
          _heroPanel(),
          const SizedBox(height: 18),
          _searchBox(submitToProducts: true),
          const SizedBox(height: 25),
          _sectionHeader('Compra por categoría', 'Ver todas', () {
            setState(() {
              _category = 'Todos';
              _page = 1;
            });
          }),
          const SizedBox(height: 12),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = _categories[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() {
                    _category = item[0] as String;
                    _page = 1;
                  }),
                  child: Container(
                    width: 98,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .03), blurRadius: 12, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 49,
                          height: 49,
                          decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(15)),
                          child: Icon(item[1] as IconData, color: AppColors.goldDark, size: 25),
                        ),
                        const SizedBox(height: 8),
                        Text(item[0] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 26),
          _benefitsStrip(),
          const SizedBox(height: 27),
          _sectionHeader('Productos destacados', 'Ver más', () {
            setState(() {
              _category = 'Todos';
              _page = 1;
            });
          }),
          const SizedBox(height: 12),
          _productGrid(productosData.take(4).toList()),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 62,
          height: 62,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: AppColors.border)),
          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/imagenes/logo_adn_imports.png', fit: BoxFit.cover)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DORADA MOTORS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: .2)),
              const SizedBox(height: 3),
              Text(
                widget.isGuest ? "ADN Import's • Explorando catálogo" : 'Hola, ${widget.userName?.split(' ').first ?? 'Cliente'} 👋',
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        _roundAction(
          icon: Icons.notifications_none_rounded,
          onTap: () {
            if (widget.isGuest) {
              _message('Inicia sesión para ver el estado de tus pedidos.');
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
            }
          },
        ),
        const SizedBox(width: 7),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _roundAction(icon: Icons.shopping_cart_outlined, onTap: _openCart),
            if (_cartCount > 0)
              Positioned(
                right: -2,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                  child: Text('$_cartCount', style: const TextStyle(color: AppColors.ink, fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _roundAction({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(width: 45, height: 45, decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)), child: Icon(icon, size: 22, color: AppColors.ink)),
      ),
    );
  }

  Widget _heroPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(21, 22, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.navy, Color(0xFF1D3260)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .18), blurRadius: 25, offset: const Offset(0, 12))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -30,
            child: Container(width: 135, height: 135, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withValues(alpha: .11))),
          ),
          Positioned(
            right: 16,
            bottom: -28,
            child: Container(width: 94, height: 94, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .04))),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .16), borderRadius: BorderRadius.circular(11)),
                      child: const Text('CALIDAD • STOCK • CONFIANZA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.gold, letterSpacing: .4)),
                    ),
                    const SizedBox(height: 13),
                    const Text('Todo para tu moto\nen un solo lugar', style: TextStyle(fontSize: 28, height: 1.08, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text('Repuestos para motocicleta y motokar con stock y compatibilidad.', style: TextStyle(fontSize: 12, height: 1.4, color: Colors.white70)),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () => setState(() {
                            _category = 'Todos';
                            _page = 1;
                          }),
                          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink, minimumSize: const Size(0, 45)),
                          child: const Text('Ver catálogo'),
                        ),
                        const SizedBox(width: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(13)),
                          child: const Row(children: [Icon(Icons.local_offer_outlined, size: 16, color: AppColors.gold), SizedBox(width: 5), Text('Hasta 25% OFF', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800))]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .13), shape: BoxShape.circle, border: Border.all(color: AppColors.gold.withValues(alpha: .3))),
                child: const Icon(Icons.two_wheeler_rounded, size: 43, color: AppColors.gold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchBox({required bool submitToProducts}) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 5))]),
            child: TextField(
              onChanged: submitToProducts ? null : (value) => setState(() => _search = value),
              onSubmitted: submitToProducts
                  ? (value) => setState(() {
                        _search = value;
                        _page = 1;
                      })
                  : null,
              decoration: const InputDecoration(hintText: 'Buscar repuestos, marcas...', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 56,
          height: 56,
          child: FilledButton(
            onPressed: _openFilters,
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.ink, padding: EdgeInsets.zero),
            child: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
    );
  }

  Widget _benefitsStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: const Row(
        children: [
          _Benefit(icon: Icons.verified_outlined, title: 'Calidad', subtitle: 'Marcas confiables'),
          _VerticalDivider(),
          _Benefit(icon: Icons.inventory_2_outlined, title: 'Stock', subtitle: 'Disponibilidad'),
          _VerticalDivider(),
          _Benefit(icon: Icons.support_agent_outlined, title: 'Soporte', subtitle: 'Compra fácil'),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String action, VoidCallback onTap) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        TextButton(onPressed: onTap, child: Row(mainAxisSize: MainAxisSize.min, children: [Text(action), const SizedBox(width: 2), const Icon(Icons.arrow_forward_rounded, size: 16)])),
      ],
    );
  }

  Widget _productsPage() {
    final products = _filteredProducts;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catálogo', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
                    SizedBox(height: 2),
                    Text('Encuentra el repuesto ideal para tu vehículo.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _roundAction(icon: Icons.shopping_cart_outlined, onTap: _openCart),
                  if (_cartCount > 0)
                    Positioned(right: -2, top: -4, child: CircleAvatar(radius: 10, backgroundColor: AppColors.gold, child: Text('$_cartCount', style: const TextStyle(fontSize: 8, color: AppColors.ink, fontWeight: FontWeight.w900)))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _searchBox(submitToProducts: false),
          const SizedBox(height: 12),
          if (_category != 'Todos' || _brand != 'Todas' || _vehicle != 'Todos')
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_category != 'Todos') Chip(label: Text(_category), onDeleted: () => setState(() => _category = 'Todos')),
                if (_brand != 'Todas') Chip(label: Text(_brand), onDeleted: () => setState(() => _brand = 'Todas')),
                if (_vehicle != 'Todos') Chip(label: Text(_vehicle), onDeleted: () => setState(() => _vehicle = 'Todos')),
              ],
            ),
          const SizedBox(height: 15),
          Row(
            children: [
              Text('${products.length} producto${products.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
              const Spacer(),
              const Icon(Icons.sort_rounded, size: 18, color: AppColors.muted),
              const SizedBox(width: 4),
              const Text('Catálogo activo', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            const _EmptyState(icon: Icons.search_off_rounded, title: 'No encontramos productos', text: 'Prueba otra búsqueda o limpia los filtros aplicados.')
          else
            _productGrid(products),
        ],
      ),
    );
  }

  Widget _favoritesPage() {
    if (widget.isGuest) {
      return _accountRequiredPage(
        icon: Icons.favorite_border_rounded,
        title: 'Guarda tus favoritos',
        text: 'Inicia sesión para guardar repuestos y encontrarlos rápidamente después.',
      );
    }
    final products = productosData.where((p) => _favorites.contains(p.id)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mis favoritos', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${products.length} producto${products.length == 1 ? '' : 's'} guardado${products.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          Expanded(
            child: products.isEmpty
                ? const _EmptyState(icon: Icons.favorite_border_rounded, title: 'Todavía no tienes favoritos', text: 'Toca el corazón de un producto para guardarlo aquí.')
                : SingleChildScrollView(child: _productGrid(products)),
          ),
        ],
      ),
    );
  }

  Widget _profilePage() {
    if (widget.isGuest) {
      return _accountRequiredPage(
        icon: Icons.person_outline_rounded,
        title: 'Tu cuenta Dorada Motors',
        text: 'Inicia sesión para acceder a pedidos, datos y opciones personales.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navySoft]),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: .16), blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .10), shape: BoxShape.circle, border: Border.all(color: AppColors.gold.withValues(alpha: .5), width: 2)),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 39),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MI CUENTA', style: TextStyle(fontSize: 9, letterSpacing: 1, color: AppColors.gold, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(widget.userName ?? 'Cliente', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 3),
                      Text(widget.userEmail ?? '', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _profileOption(Icons.receipt_long_outlined, 'Mis pedidos', 'Revisa compras, totales y estados', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
          }),
          _profileOption(Icons.location_on_outlined, 'Direcciones', 'Se registra durante el delivery', () {
            _message('Puedes registrar la dirección al finalizar una compra con Delivery.');
          }),
          _profileOption(Icons.help_outline_rounded, 'Ayuda y soporte', 'Información de la aplicación', () {
            showAboutDialog(
              context: context,
              applicationName: 'Dorada Motors',
              applicationVersion: '1.0.0',
              children: const [Text("Aplicación de ADN Import's para consultar y comprar repuestos de motocicletas y motokar.")],
            );
          }),
          _profileOption(Icons.settings_outlined, 'Configuración', 'Preferencias de la aplicación', () {
            _message('Configuración lista para futuras preferencias.');
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                await LocalStore.logout();
                widget.onLogout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppColors.goldDark)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountRequiredPage({required IconData icon, required String title, required String text}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppColors.border)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 88, height: 88, decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle), child: Icon(icon, size: 44, color: AppColors.goldDark)),
                const SizedBox(height: 18),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.45)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: widget.onLoginRequested, icon: const Icon(Icons.login_rounded), label: const Text('Iniciar sesión / Registrarme'))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _productGrid(List<Producto> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: .60,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          favorite: _favorites.contains(product.id),
          onTap: () => _openProduct(product),
          onFavorite: () => _toggleFavorite(product.id),
          onAddCart: () => _addCart(product.id),
        );
      },
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Benefit({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.goldDark, size: 21),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 1),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 38, color: AppColors.border);
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyState({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 82, height: 82, decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle), child: Icon(icon, size: 39, color: AppColors.goldDark)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _CartEmpty extends StatelessWidget {
  const _CartEmpty();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(icon: Icons.shopping_cart_outlined, title: 'Tu carrito está vacío', text: 'Agrega productos desde el catálogo para continuar con tu compra.');
  }
}
