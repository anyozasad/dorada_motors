<?php

require_once "conexion.php";

function limpiar($dato)
{
    return htmlspecialchars((string)$dato, ENT_QUOTES, "UTF-8");
}

/* =====================================================
   REGISTRAR PRODUCTO - CREATE
===================================================== */

if (isset($_POST["registrar_producto"])) {

    $id_categoria = (int) $_POST["id_categoria"];
    $id_marca = (int) $_POST["id_marca"];
    $nombre = $_POST["nombre_producto"];
    $descripcion = $_POST["descripcion"];
    $precio = (float) $_POST["precio"];
    $stock = (int) $_POST["stock"];
    $imagen = $_POST["imagen_url"];

    $sql = "INSERT INTO producto
            (
                id_categoria,
                id_marca,
                nombre_producto,
                descripcion,
                precio,
                stock,
                imagen_url
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)";

    $stmt = $conexion->prepare($sql);

    $stmt->bind_param(
        "iissdis",
        $id_categoria,
        $id_marca,
        $nombre,
        $descripcion,
        $precio,
        $stock,
        $imagen
    );

    $stmt->execute();

    header("Location: dashboard.php?mensaje=registrado");
    exit;
}


/* =====================================================
   ACTUALIZAR PRODUCTO - UPDATE
===================================================== */

if (isset($_POST["actualizar_producto"])) {

    $id_producto = (int) $_POST["id_producto"];
    $id_categoria = (int) $_POST["id_categoria"];
    $id_marca = (int) $_POST["id_marca"];
    $nombre = $_POST["nombre_producto"];
    $descripcion = $_POST["descripcion"];
    $precio = (float) $_POST["precio"];
    $stock = (int) $_POST["stock"];
    $imagen = $_POST["imagen_url"];

    $sql = "UPDATE producto SET
                id_categoria = ?,
                id_marca = ?,
                nombre_producto = ?,
                descripcion = ?,
                precio = ?,
                stock = ?,
                imagen_url = ?
            WHERE id_producto = ?";

    $stmt = $conexion->prepare($sql);

    $stmt->bind_param(
        "iissdisi",
        $id_categoria,
        $id_marca,
        $nombre,
        $descripcion,
        $precio,
        $stock,
        $imagen,
        $id_producto
    );

    $stmt->execute();

    header("Location: dashboard.php?mensaje=actualizado");
    exit;
}


/* =====================================================
   ELIMINAR PRODUCTO - DELETE
===================================================== */

if (isset($_POST["eliminar_producto"])) {

    $id_producto = (int) $_POST["id_producto"];

    /* Comprobar si ya pertenece a un pedido */

    $stmt = $conexion->prepare(
        "SELECT COUNT(*) AS cantidad
         FROM detalle_pedido
         WHERE id_producto = ?"
    );

    $stmt->bind_param("i", $id_producto);

    $stmt->execute();

    $resultado = $stmt->get_result()->fetch_assoc();

    if ($resultado["cantidad"] > 0) {

        header(
            "Location: dashboard.php?mensaje=no_eliminar"
        );

        exit;
    }

    /* Eliminar favoritos relacionados */

    $stmt = $conexion->prepare(
        "DELETE FROM carrito_favorito
         WHERE id_producto = ?"
    );

    $stmt->bind_param("i", $id_producto);

    $stmt->execute();


    /* Eliminar producto */

    $stmt = $conexion->prepare(
        "DELETE FROM producto
         WHERE id_producto = ?"
    );

    $stmt->bind_param("i", $id_producto);

    $stmt->execute();

    header("Location: dashboard.php?mensaje=eliminado");

    exit;
}


/* =====================================================
   DATOS PARA DASHBOARD
===================================================== */

$totalProductos = $conexion->query(
    "SELECT COUNT(*) AS total FROM producto"
)->fetch_assoc()["total"];


$totalUsuarios = $conexion->query(
    "SELECT COUNT(*) AS total FROM usuario"
)->fetch_assoc()["total"];


$totalPedidos = $conexion->query(
    "SELECT COUNT(*) AS total FROM pedido"
)->fetch_assoc()["total"];


$totalVentas = $conexion->query(
    "SELECT IFNULL(SUM(total),0) AS total
     FROM pedido"
)->fetch_assoc()["total"];


/* =====================================================
   CATEGORÍAS
===================================================== */

$categorias = $conexion->query(
    "SELECT * FROM categoria
     ORDER BY nombre_categoria"
);


/* =====================================================
   MARCAS
===================================================== */

$marcas = $conexion->query(
    "SELECT * FROM marca
     ORDER BY nombre_marca"
);


/* =====================================================
   PRODUCTOS - READ
===================================================== */

$productos = $conexion->query(
    "SELECT
        p.id_producto,
        p.id_categoria,
        p.id_marca,
        p.nombre_producto,
        p.descripcion,
        p.precio,
        p.stock,
        p.imagen_url,
        c.nombre_categoria,
        m.nombre_marca

     FROM producto p

     INNER JOIN categoria c
        ON p.id_categoria = c.id_categoria

     INNER JOIN marca m
        ON p.id_marca = m.id_marca

     ORDER BY p.id_producto DESC"
);


/* =====================================================
   ÚLTIMOS PEDIDOS
===================================================== */

$pedidos = $conexion->query(
    "SELECT
        p.id_pedido,
        p.fecha_pedido,
        p.estado_pedido,
        p.total,
        u.nombres,
        u.apellidos

     FROM pedido p

     INNER JOIN usuario u
        ON p.id_usuario = u.id_usuario

     ORDER BY p.id_pedido DESC

     LIMIT 5"
);


/* =====================================================
   PRODUCTO PARA EDITAR
===================================================== */

$productoEditar = null;

if (isset($_GET["editar"])) {

    $id = (int) $_GET["editar"];

    $stmt = $conexion->prepare(
        "SELECT *
         FROM producto
         WHERE id_producto = ?"
    );

    $stmt->bind_param("i", $id);

    $stmt->execute();

    $productoEditar =
        $stmt->get_result()->fetch_assoc();
}

?>

<!DOCTYPE html>

<html lang="es">

<head>

    <meta charset="UTF-8">

    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <title>
        Dorada Motors - Dashboard
    </title>


    <style>
        * {
            box-sizing: border-box;
        }

        body {

            margin: 0;

            font-family:
                Arial,
                Helvetica,
                sans-serif;

            background: #f5f6fa;

            color: #101828;
        }


        /* HEADER */

        header {

            background:
                linear-gradient(135deg,
                    #0f1b33,
                    #1e315b);

            color: white;

            padding:
                22px 35px;

            display: flex;

            justify-content:
                space-between;

            align-items: center;

        }


        .logo h1 {

            margin: 0;

            font-size: 26px;
        }


        .logo span {

            color: #e2b11f;
        }


        .logo p {

            margin:
                5px 0 0;

            color:
                #d0d5dd;

            font-size: 13px;
        }


        /* CONTENEDOR */

        .contenedor {

            width: 92%;

            max-width: 1400px;

            margin:
                30px auto;
        }


        /* TITULO */

        .titulo {

            margin-bottom: 20px;
        }


        .titulo h2 {

            margin-bottom: 5px;
        }


        .titulo p {

            color: #667085;

            margin-top: 0;
        }


        /* TARJETAS */

        .tarjetas {

            display: grid;

            grid-template-columns:
                repeat(4, 1fr);

            gap: 18px;

            margin-bottom: 30px;
        }


        .tarjeta {

            background: white;

            border-radius: 18px;

            padding: 22px;

            box-shadow:
                0 5px 20px rgba(0, 0, 0, .06);

            border:
                1px solid #e6e8ee;
        }


        .tarjeta small {

            color: #667085;

            font-weight: bold;
        }


        .tarjeta h2 {

            color: #0f1b33;

            font-size: 30px;

            margin:
                10px 0 0;
        }


        .tarjeta.ventas h2 {

            color: #c79400;
        }


        /* CAJAS */

        .caja {

            background: white;

            border-radius: 20px;

            padding: 24px;

            margin-bottom: 25px;

            box-shadow:
                0 5px 20px rgba(0, 0, 0, .05);

            border:
                1px solid #e6e8ee;
        }


        .caja h2 {

            color: #0f1b33;

            margin-top: 0;
        }


        /* FORMULARIO */

        .formulario {

            display: grid;

            grid-template-columns:
                repeat(2, 1fr);

            gap: 15px;
        }


        .campo {

            display: flex;

            flex-direction: column;
        }


        .campo label {

            font-size: 13px;

            font-weight: bold;

            margin-bottom: 6px;

            color: #667085;
        }


        input,
        select,
        textarea {

            padding: 12px;

            border:
                1px solid #d0d5dd;

            border-radius: 10px;

            font-size: 14px;
        }


        textarea {

            min-height: 90px;

            resize: vertical;
        }


        .completo {

            grid-column:
                1 / -1;
        }


        /* BOTONES */

        button,
        .boton {

            border: none;

            padding:
                11px 17px;

            border-radius: 10px;

            cursor: pointer;

            font-weight: bold;

            text-decoration: none;

            display: inline-block;
        }


        .guardar {

            background: #0f1b33;

            color: white;
        }


        .editar {

            background: #e2b11f;

            color: #101828;
        }


        .eliminar {

            background: #ffe3e0;

            color: #d92d20;
        }


        .cancelar {

            background: #e6e8ee;

            color: #101828;
        }


        /* TABLAS */

        .tabla {

            overflow-x: auto;
        }


        table {

            width: 100%;

            border-collapse:
                collapse;

            min-width: 900px;
        }


        th {

            background: #0f1b33;

            color: white;

            padding: 12px;

            text-align: left;

            font-size: 13px;
        }


        td {

            padding: 12px;

            border-bottom:
                1px solid #e6e8ee;

            font-size: 13px;
        }


        tr:hover {

            background:
                #fafafa;
        }


        .precio {

            font-weight: bold;

            color: #0f1b33;
        }


        /* ESTADOS */

        .stock {

            padding:
                5px 9px;

            border-radius: 10px;

            font-weight: bold;
        }


        .stock-bien {

            background:
                #e8f7ef;

            color:
                #17854b;
        }


        .stock-bajo {

            background:
                #fff3c4;

            color:
                #8b6500;
        }


        .stock-cero {

            background:
                #ffe3e0;

            color:
                #d92d20;
        }


        /* MENSAJES */

        .mensaje {

            padding: 13px;

            border-radius: 10px;

            margin-bottom: 20px;

            font-weight: bold;
        }


        .correcto {

            background:
                #e8f7ef;

            color:
                #17854b;
        }


        .error {

            background:
                #ffe3e0;

            color:
                #d92d20;
        }


        /* CRUD */

        .crud {

            background:
                #fff3c4;

            color:
                #8b6500;

            padding:
                7px 12px;

            border-radius: 10px;

            font-size: 12px;

            font-weight: bold;
        }


        /* RESPONSIVE */

        @media (max-width: 900px) {

            .tarjetas {

                grid-template-columns:
                    repeat(2, 1fr);
            }

        }


        @media (max-width: 600px) {

            .tarjetas {

                grid-template-columns:
                    1fr;
            }


            .formulario {

                grid-template-columns:
                    1fr;
            }

        }
    </style>

</head>


<body>


    <header>

        <div class="logo">

            <h1>
                DORADA
                <span>MOTORS</span>
            </h1>

            <p>
                Panel de administración PHP + MySQL
            </p>

        </div>


        <div>

            API CONECTADA ✓

        </div>

    </header>


    <div class="contenedor">


        <?php

        if (isset($_GET["mensaje"])) {

            $m = $_GET["mensaje"];

            if ($m == "registrado") {

                echo '
        <div class="mensaje correcto">
        Producto registrado correctamente.
        </div>
        ';
            }


            if ($m == "actualizado") {

                echo '
        <div class="mensaje correcto">
        Producto actualizado correctamente.
        </div>
        ';
            }


            if ($m == "eliminado") {

                echo '
        <div class="mensaje correcto">
        Producto eliminado correctamente.
        </div>
        ';
            }


            if ($m == "no_eliminar") {

                echo '
        <div class="mensaje error">
        Este producto ya pertenece a un pedido y no puede eliminarse.
        </div>
        ';
            }
        }

        ?>


        <div class="titulo">

            <h2>
                Dashboard
            </h2>

            <p>
                Datos obtenidos directamente desde
                la base de datos dorada_motors.
            </p>

        </div>


        <!-- DASHBOARD -->


        <div class="tarjetas">


            <div class="tarjeta">

                <small>
                    PRODUCTOS
                </small>

                <h2>
                    <?php echo $totalProductos; ?>
                </h2>

            </div>


            <div class="tarjeta">

                <small>
                    USUARIOS
                </small>

                <h2>
                    <?php echo $totalUsuarios; ?>
                </h2>

            </div>


            <div class="tarjeta">

                <small>
                    PEDIDOS
                </small>

                <h2>
                    <?php echo $totalPedidos; ?>
                </h2>

            </div>


            <div class="tarjeta ventas">

                <small>
                    TOTAL VENTAS
                </small>

                <h2>

                    S/
                    <?php

                    echo number_format(
                        $totalVentas,
                        2
                    );

                    ?>

                </h2>

            </div>


        </div>



        <!-- FORMULARIO -->


        <div class="caja">

            <div style="
display:flex;
justify-content:space-between;
align-items:center;
">

                <h2>

                    <?php

                    echo $productoEditar
                        ? "Editar producto"
                        : "Registrar producto";

                    ?>

                </h2>


                <span class="crud">

                    <?php

                    echo $productoEditar
                        ? "UPDATE"
                        : "CREATE";

                    ?>

                </span>

            </div>


            <form method="POST" class="formulario">


                <?php

                if ($productoEditar) {

                ?>

                    <input type="hidden" name="id_producto" value="<?php
                                                                    echo limpiar(
                                                                        $productoEditar["id_producto"]
                                                                    );
                                                                    ?>">

                <?php

                }

                ?>


                <div class="campo">

                    <label>
                        Nombre del producto
                    </label>

                    <input type="text" name="nombre_producto" required value="<?php
                                                                                echo limpiar(
                                                                                    $productoEditar["nombre_producto"]
                                                                                        ?? ""
                                                                                );
                                                                                ?>">

                </div>



                <div class="campo">

                    <label>
                        Categoría
                    </label>

                    <select name="id_categoria" required>

                        <option value="">
                            Seleccione categoría
                        </option>


                        <?php

                        mysqli_data_seek(
                            $categorias,
                            0
                        );

                        while (
                            $categoria =
                            $categorias->fetch_assoc()
                        ) {

                        ?>

                            <option value="<?php
                                            echo $categoria["id_categoria"];
                                            ?>" <?php

                            if (
                                $productoEditar
                                &&
                                $productoEditar["id_categoria"]
                                ==
                                $categoria["id_categoria"]
                            ) {

                                echo "selected";
                            }

    ?>>

                                <?php
                                echo limpiar(
                                    $categoria["nombre_categoria"]
                                );
                                ?>

                            </option>

                        <?php

                        }

                        ?>

                    </select>

                </div>



                <div class="campo">

                    <label>
                        Marca
                    </label>

                    <select name="id_marca" required>

                        <option value="">
                            Seleccione marca
                        </option>


                        <?php

                        mysqli_data_seek(
                            $marcas,
                            0
                        );

                        while (
                            $marca =
                            $marcas->fetch_assoc()
                        ) {

                        ?>

                            <option value="<?php
                                            echo $marca["id_marca"];
                                            ?>" <?php

                            if (
                                $productoEditar
                                &&
                                $productoEditar["id_marca"]
                                ==
                                $marca["id_marca"]
                            ) {

                                echo "selected";
                            }

    ?>>

                                <?php
                                echo limpiar(
                                    $marca["nombre_marca"]
                                );
                                ?>

                            </option>

                        <?php

                        }

                        ?>

                    </select>

                </div>



                <div class="campo">

                    <label>
                        Precio
                    </label>

                    <input type="number" step="0.01" min="0" name="precio" required value="<?php
                                                                                            echo limpiar(
                                                                                                $productoEditar["precio"]
                                                                                                    ?? ""
                                                                                            );
                                                                                            ?>">

                </div>



                <div class="campo">

                    <label>
                        Stock
                    </label>

                    <input type="number" min="0" name="stock" required value="<?php
                                                                                echo limpiar(
                                                                                    $productoEditar["stock"]
                                                                                        ?? ""
                                                                                );
                                                                                ?>">

                </div>



                <div class="campo">

                    <label>
                        Imagen
                    </label>

                    <input type="text" name="imagen_url" placeholder="producto.png" value="<?php
                                                                                            echo limpiar(
                                                                                                $productoEditar["imagen_url"]
                                                                                                    ?? ""
                                                                                            );
                                                                                            ?>">

                </div>



                <div class="campo completo">

                    <label>
                        Descripción
                    </label>

                    <textarea name="descripcion"><?php

                                                    echo limpiar(
                                                        $productoEditar["descripcion"]
                                                            ?? ""
                                                    );

                                                    ?></textarea>

                </div>



                <div class="completo">


                    <?php

                    if ($productoEditar) {

                    ?>

                        <button type="submit" name="actualizar_producto" class="editar">

                            Guardar cambios

                        </button>


                        <a href="dashboard.php" class="boton cancelar">

                            Cancelar

                        </a>


                    <?php

                    } else {

                    ?>


                        <button type="submit" name="registrar_producto" class="guardar">

                            Registrar producto

                        </button>


                    <?php

                    }

                    ?>


                </div>


            </form>

        </div>



        <!-- PRODUCTOS CRUD -->


        <div class="caja">


            <div style="
display:flex;
justify-content:space-between;
align-items:center;
">


                <h2>
                    Productos registrados
                </h2>


                <span class="crud">
                    CRUD COMPLETO
                </span>


            </div>


            <div class="tabla">


                <table>


                    <thead>

                        <tr>

                            <th>ID</th>

                            <th>Producto</th>

                            <th>Categoría</th>

                            <th>Marca</th>

                            <th>Precio</th>

                            <th>Stock</th>

                            <th>Acciones</th>

                        </tr>

                    </thead>


                    <tbody>


                        <?php


                        while (
                            $producto =
                            $productos->fetch_assoc()
                        ) {


                            $stock =
                                (int)$producto["stock"];


                            if ($stock <= 0) {

                                $claseStock =
                                    "stock-cero";
                            } elseif ($stock <= 5) {

                                $claseStock =
                                    "stock-bajo";
                            } else {

                                $claseStock =
                                    "stock-bien";
                            }


                        ?>


                            <tr>


                                <td>

                                    <?php
                                    echo $producto["id_producto"];
                                    ?>

                                </td>


                                <td>

                                    <strong>

                                        <?php

                                        echo limpiar(
                                            $producto["nombre_producto"]
                                        );

                                        ?>

                                    </strong>


                                    <br>


                                    <small style="color:#667085;">

                                        <?php

                                        echo limpiar(
                                            $producto["descripcion"]
                                        );

                                        ?>

                                    </small>

                                </td>


                                <td>

                                    <?php

                                    echo limpiar(
                                        $producto["nombre_categoria"]
                                    );

                                    ?>

                                </td>


                                <td>

                                    <?php

                                    echo limpiar(
                                        $producto["nombre_marca"]
                                    );

                                    ?>

                                </td>


                                <td class="precio">

                                    S/

                                    <?php

                                    echo number_format(
                                        $producto["precio"],
                                        2
                                    );

                                    ?>

                                </td>


                                <td>

                                    <span class="stock
<?php echo $claseStock; ?>">

                                        <?php
                                        echo $stock;
                                        ?>

                                    </span>

                                </td>


                                <td>


                                    <a href="dashboard.php?editar=<?php
                                                                    echo $producto["id_producto"];
                                                                    ?>" class="boton editar">

                                        Editar

                                    </a>


                                    <form method="POST" style="
display:inline-block;
" onsubmit="
return confirm(
'¿Seguro que deseas eliminar este producto?'
);
">


                                        <input type="hidden" name="id_producto" value="<?php
                                                                                        echo $producto["id_producto"];
                                                                                        ?>">


                                        <button type="submit" name="eliminar_producto" class="eliminar">

                                            Eliminar

                                        </button>


                                    </form>


                                </td>


                            </tr>


                        <?php

                        }

                        ?>


                    </tbody>


                </table>


            </div>


        </div>



        <!-- PEDIDOS -->


        <div class="caja">


            <h2>
                Últimos pedidos
            </h2>


            <div class="tabla">


                <table>


                    <thead>


                        <tr>

                            <th>Pedido</th>

                            <th>Cliente</th>

                            <th>Fecha</th>

                            <th>Estado</th>

                            <th>Total</th>

                        </tr>


                    </thead>


                    <tbody>


                        <?php


                        if ($pedidos->num_rows == 0) {


                        ?>


                            <tr>

                                <td colspan="5" style="text-align:center;">

                                    Todavía no existen pedidos.

                                </td>

                            </tr>


                            <?php


                        } else {


                            while (
                                $pedido =
                                $pedidos->fetch_assoc()
                            ) {


                            ?>


                                <tr>


                                    <td>

                                        #<?php
                                            echo $pedido["id_pedido"];
                                            ?>

                                    </td>


                                    <td>

                                        <?php

                                        echo limpiar(
                                            $pedido["nombres"]
                                                .
                                                " "
                                                .
                                                $pedido["apellidos"]
                                        );

                                        ?>

                                    </td>


                                    <td>

                                        <?php

                                        echo limpiar(
                                            $pedido["fecha_pedido"]
                                        );

                                        ?>

                                    </td>


                                    <td>

                                        <?php

                                        echo limpiar(
                                            $pedido["estado_pedido"]
                                        );

                                        ?>

                                    </td>


                                    <td class="precio">

                                        S/

                                        <?php

                                        echo number_format(
                                            $pedido["total"],
                                            2
                                        );

                                        ?>

                                    </td>


                                </tr>


                        <?php


                            }
                        }


                        ?>


                    </tbody>


                </table>


            </div>


        </div>


    </div>


</body>

</html>