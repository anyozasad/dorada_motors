CREATE DATABASE IF NOT EXISTS dorada_motors
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE dorada_motors;

SET FOREIGN_KEY_CHECKS=0;

CREATE TABLE IF NOT EXISTS usuario (
  id_usuario INT AUTO_INCREMENT PRIMARY KEY,
  nombres VARCHAR(120) NOT NULL,
  apellidos VARCHAR(120) NOT NULL DEFAULT '',
  correo VARCHAR(160) NOT NULL UNIQUE,
  contrasena VARCHAR(255) NOT NULL,
  telefono VARCHAR(30) NOT NULL DEFAULT '',
  estado VARCHAR(20) NOT NULL DEFAULT 'Activo',
  rol_sistema VARCHAR(20) NOT NULL DEFAULT 'Cliente',
  ultimo_acceso DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS direccion (
  id_direccion INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT NOT NULL,
  departamento VARCHAR(100) NOT NULL,
  provincia VARCHAR(100) NOT NULL,
  distrito VARCHAR(100) NOT NULL,
  direccion_detalle VARCHAR(255) NOT NULL,
  referencia VARCHAR(255) NOT NULL DEFAULT '',
  INDEX idx_direccion_usuario (id_usuario),
  CONSTRAINT fk_direccion_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS categoria (
  id_categoria INT AUTO_INCREMENT PRIMARY KEY,
  nombre_categoria VARCHAR(120) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS marca (
  id_marca INT AUTO_INCREMENT PRIMARY KEY,
  nombre_marca VARCHAR(120) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS producto (
  id_producto INT AUTO_INCREMENT PRIMARY KEY,
  id_categoria INT NOT NULL,
  id_marca INT NOT NULL,
  nombre_producto VARCHAR(180) NOT NULL,
  descripcion TEXT NULL,
  tipo_vehiculo VARCHAR(50) NOT NULL DEFAULT 'Motocicleta / Motokar',
  compatibilidad VARCHAR(255) NOT NULL DEFAULT '',
  precio DECIMAL(10,2) NOT NULL DEFAULT 0,
  precio_oferta DECIMAL(10,2) NULL,
  stock INT NOT NULL DEFAULT 0,
  stock_minimo INT NOT NULL DEFAULT 5,
  imagen_url VARCHAR(255) NOT NULL DEFAULT '',
  INDEX idx_producto_categoria (id_categoria),
  INDEX idx_producto_marca (id_marca),
  CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria)
    REFERENCES categoria(id_categoria) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_producto_marca FOREIGN KEY (id_marca)
    REFERENCES marca(id_marca) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS pedido (
  id_pedido INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT NOT NULL,
  fecha_pedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado_pedido VARCHAR(30) NOT NULL DEFAULT 'Pendiente',
  total DECIMAL(10,2) NOT NULL DEFAULT 0,
  id_direccion INT NULL,
  tipo_entrega VARCHAR(30) NOT NULL DEFAULT 'Recojo en tienda',
  INDEX idx_pedido_usuario (id_usuario),
  INDEX idx_pedido_direccion (id_direccion),
  INDEX idx_pedido_fecha (fecha_pedido),
  CONSTRAINT fk_pedido_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_pedido_direccion FOREIGN KEY (id_direccion)
    REFERENCES direccion(id_direccion) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS detalle_pedido (
  id_detalle INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  id_producto INT NOT NULL,
  cantidad INT NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL DEFAULT 0,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  INDEX idx_detalle_pedido (id_pedido),
  INDEX idx_detalle_producto (id_producto),
  CONSTRAINT fk_detalle_pedido FOREIGN KEY (id_pedido)
    REFERENCES pedido(id_pedido) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS pago (
  id_pago INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  metodo_pago VARCHAR(50) NOT NULL,
  monto DECIMAL(10,2) NOT NULL DEFAULT 0,
  fecha_pago DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  estado_pago VARCHAR(30) NOT NULL DEFAULT 'Pendiente',
  INDEX idx_pago_pedido (id_pedido),
  CONSTRAINT fk_pago_pedido FOREIGN KEY (id_pedido)
    REFERENCES pedido(id_pedido) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS proveedor (
  id_proveedor INT AUTO_INCREMENT PRIMARY KEY,
  razon_social VARCHAR(180) NOT NULL,
  ruc VARCHAR(20) NULL,
  telefono VARCHAR(30) NULL,
  correo VARCHAR(160) NULL,
  direccion VARCHAR(255) NULL,
  estado VARCHAR(20) NOT NULL DEFAULT 'Activo'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS compra (
  id_compra INT AUTO_INCREMENT PRIMARY KEY,
  id_proveedor INT NOT NULL,
  fecha_compra DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total DECIMAL(10,2) NOT NULL DEFAULT 0,
  estado VARCHAR(30) NOT NULL DEFAULT 'Registrado',
  INDEX idx_compra_proveedor (id_proveedor),
  INDEX idx_compra_fecha (fecha_compra),
  CONSTRAINT fk_compra_proveedor FOREIGN KEY (id_proveedor)
    REFERENCES proveedor(id_proveedor) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS detalle_compra (
  id_detalle_compra INT AUTO_INCREMENT PRIMARY KEY,
  id_compra INT NOT NULL,
  id_producto INT NOT NULL,
  cantidad INT NOT NULL,
  precio_compra DECIMAL(10,2) NOT NULL DEFAULT 0,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  INDEX idx_detalle_compra_compra (id_compra),
  INDEX idx_detalle_compra_producto (id_producto),
  CONSTRAINT fk_detalle_compra FOREIGN KEY (id_compra)
    REFERENCES compra(id_compra) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_detalle_compra_producto FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS movimiento_stock (
  id_movimiento INT AUTO_INCREMENT PRIMARY KEY,
  id_producto INT NOT NULL,
  tipo_movimiento VARCHAR(20) NOT NULL,
  cantidad INT NOT NULL,
  motivo VARCHAR(255) NULL,
  fecha_movimiento DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  stock_anterior INT NULL,
  stock_nuevo INT NULL,
  INDEX idx_movimiento_producto (id_producto),
  INDEX idx_movimiento_fecha (fecha_movimiento),
  CONSTRAINT fk_movimiento_producto FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS comprobante (
  id_comprobante INT AUTO_INCREMENT PRIMARY KEY,
  id_pedido INT NOT NULL,
  tipo_comprobante VARCHAR(20) NOT NULL DEFAULT 'Boleta',
  numero_comprobante VARCHAR(40) NOT NULL UNIQUE,
  fecha_emision DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  igv DECIMAL(10,2) NOT NULL DEFAULT 0,
  total DECIMAL(10,2) NOT NULL DEFAULT 0,
  INDEX idx_comprobante_pedido (id_pedido),
  CONSTRAINT fk_comprobante_pedido FOREIGN KEY (id_pedido)
    REFERENCES pedido(id_pedido) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sesion_cliente (
  token_hash CHAR(64) NOT NULL PRIMARY KEY,
  id_usuario INT NOT NULL,
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_expiracion DATETIME NOT NULL,
  INDEX idx_sesion_cliente_usuario (id_usuario),
  INDEX idx_sesion_cliente_expiracion (fecha_expiracion),
  CONSTRAINT fk_sesion_cliente_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS carrito (
  id_carrito INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT NOT NULL,
  estado VARCHAR(20) NOT NULL DEFAULT 'Activo',
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_carrito_usuario (id_usuario),
  CONSTRAINT fk_carrito_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS detalle_carrito (
  id_detalle_carrito INT AUTO_INCREMENT PRIMARY KEY,
  id_carrito INT NOT NULL,
  id_producto INT NOT NULL,
  cantidad INT NOT NULL,
  UNIQUE KEY uq_detalle_carrito (id_carrito,id_producto),
  INDEX idx_detalle_carrito_producto (id_producto),
  CONSTRAINT fk_detalle_carrito_carrito FOREIGN KEY (id_carrito)
    REFERENCES carrito(id_carrito) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_detalle_carrito_producto FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS favorito (
  id_favorito INT AUTO_INCREMENT PRIMARY KEY,
  id_usuario INT NOT NULL,
  id_producto INT NOT NULL,
  fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_favorito_usuario_producto (id_usuario,id_producto),
  INDEX idx_favorito_producto (id_producto),
  CONSTRAINT fk_favorito_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_favorito_producto FOREIGN KEY (id_producto)
    REFERENCES producto(id_producto) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO categoria (nombre_categoria) VALUES
('Transmisión'),
('Frenos'),
('Motor'),
('Eléctrico'),
('Accesorios');

INSERT IGNORE INTO marca (nombre_marca) VALUES
('DTIEX'),
('GDM'),
('BJR'),
('KIGKOL');

-- Catálogo de demostración para una base recién instalada.

-- No se insertan productos si ya existe inventario en MySQL.

INSERT IGNORE INTO categoria (nombre_categoria) VALUES ('Motor'),('Frenos'),('Luces'),('Llantas'),('Aceites'),('Suspensión'),('Eléctrico'),('Accesorios');

INSERT IGNORE INTO marca (nombre_marca) VALUES ('DTIEX'),('GDM'),('KIGKOL'),('BJR'),('NGK'),('TVS'),('LIFAN');

SET @sembrar_catalogo_dorada = (SELECT COUNT(*)=0 FROM producto);

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Kit de transmisión','Kit completo de transmisión para uso diario, con cadena y coronas de alta resistencia.','Motocicleta','Modelos 125cc a 200cc según medida',185.00,169.00,14,5,'assets/imagenes/01_kit_transmision_dtiex.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Motor'
AND m.nombre_marca='DTIEX'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Pastillas de freno','Pastillas de freno delanteras con buen agarre y respuesta estable.','Motocicleta','Consultar modelo y cáliper',45.00,NULL,22,5,'assets/imagenes/02_pastillas_freno_dtiex.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Frenos'
AND m.nombre_marca='DTIEX'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Faro LED','Faro LED de alta iluminación para conducción nocturna.','Motocicleta / Motokar','Sistema 12V',95.00,NULL,10,5,'assets/imagenes/03_faro_led_gdm.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Luces'
AND m.nombre_marca='GDM'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Llanta 450-12 Motokar','Llanta reforzada para motokar, diseñada para carga y uso urbano.','Motokar','Aro 12, medida 4.50-12',210.00,NULL,8,5,'assets/imagenes/04_llanta_kigkol_450_12.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Llantas'
AND m.nombre_marca='KIGKOL'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Aceite 20W-50','Aceite de motor 4T para protección y lubricación en uso diario.','Motocicleta / Motokar','Motores 4 tiempos',35.00,NULL,35,5,'assets/imagenes/05_aceite_gdm_20w50.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Aceites'
AND m.nombre_marca='GDM'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Filtro de aire','Filtro de aire para ayudar a proteger el motor de polvo e impurezas.','Motocicleta','Verificar medida antes de comprar',40.00,NULL,18,5,'assets/imagenes/06_filtro_aire_dtiex.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Motor'
AND m.nombre_marca='DTIEX'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Amortiguadores','Par de amortiguadores posteriores para mejorar estabilidad y comodidad.','Motocicleta','Consultar longitud y anclaje',165.00,NULL,9,5,'assets/imagenes/07_amortiguadores_bjr.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Suspensión'
AND m.nombre_marca='BJR'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Batería 12V','Batería de 12 voltios para sistema eléctrico y arranque.','Motocicleta / Motokar','Sistema eléctrico 12V',120.00,NULL,12,5,'assets/imagenes/08_bateria_kigkol_12v.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Eléctrico'
AND m.nombre_marca='KIGKOL'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Carburador','Carburador de reemplazo para una mezcla estable de aire y combustible.','Motocicleta','Consultar diámetro y cilindrada',110.00,NULL,7,5,'assets/imagenes/09_carburador_dtiex.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Motor'
AND m.nombre_marca='DTIEX'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Disco de freno','Disco de freno ventilado para una frenada uniforme.','Motocicleta','Verificar diámetro y perforaciones',89.00,NULL,11,5,'assets/imagenes/10_disco_freno_gdm.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Frenos'
AND m.nombre_marca='GDM'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Bujía','Bujía para encendido estable y mantenimiento preventivo.','Motocicleta / Motokar','Consultar código recomendado por el motor',25.00,NULL,40,5,'assets/imagenes/11_bujia_ngk.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Motor'
AND m.nombre_marca='NGK'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Cadena reforzada','Cadena reforzada para transmisión con buena resistencia al desgaste.','Motocicleta','Verificar paso y cantidad de eslabones',75.00,NULL,16,5,'assets/imagenes/12_cadena_kigkol.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Motor'
AND m.nombre_marca='KIGKOL'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Espejos retrovisores','Juego de espejos retrovisores para mejor visibilidad y seguridad.','Motocicleta','Rosca estándar según modelo',55.00,NULL,20,5,'assets/imagenes/13_espejos_gdm.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Accesorios'
AND m.nombre_marca='GDM'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Pastillas de freno TVS','Pastillas de freno de reemplazo para modelos compatibles TVS.','Motocicleta / Motokar','Modelos TVS compatibles',48.00,NULL,15,5,'assets/imagenes/14_pastillas_freno_tvs.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Frenos'
AND m.nombre_marca='TVS'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Tapa de motor Lifan','Tapa lateral de motor para reposición y mantenimiento.','Motocicleta / Motokar','Motores Lifan según modelo',85.00,NULL,6,5,'assets/imagenes/15_tapa_motor_lifan.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Motor'
AND m.nombre_marca='LIFAN'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Tanque de combustible','Tanque de combustible de reemplazo para modelos compatibles.','Motocicleta','Verificar puntos de anclaje',145.00,NULL,5,5,'assets/imagenes/16_tanque_combustible_kigkol.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Motor'
AND m.nombre_marca='KIGKOL'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'CDI Racing','Módulo CDI para sistema de encendido en modelos compatibles.','Motocicleta','Verificar conectores y sistema de encendido',68.00,NULL,13,5,'assets/imagenes/17_cdi_bjr_racing.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Eléctrico'
AND m.nombre_marca='BJR'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Luz trasera','Luz trasera para señalización y seguridad vial.','Motocicleta / Motokar','Sistema 12V',70.00,NULL,14,5,'assets/imagenes/18_luz_trasera_bjr.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Luces'
AND m.nombre_marca='BJR'
AND @sembrar_catalogo_dorada=1;

INSERT INTO producto
(id_categoria,id_marca,nombre_producto,descripcion,tipo_vehiculo,compatibilidad,precio,precio_oferta,stock,stock_minimo,imagen_url)
SELECT c.id_categoria,m.id_marca,'Direccionales LED','Juego de direccionales LED para mayor visibilidad.','Motocicleta / Motokar','Sistema 12V',65.00,NULL,17,5,'assets/imagenes/19_direccionales_led.png'
FROM categoria c CROSS JOIN marca m
WHERE c.nombre_categoria='Luces'
AND m.nombre_marca='GDM'
AND @sembrar_catalogo_dorada=1;

SET FOREIGN_KEY_CHECKS=1;
