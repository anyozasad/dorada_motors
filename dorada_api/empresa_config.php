<?php
declare(strict_types=1);

function empresaConfigRuta(): string {
    return __DIR__ . "/data/config_empresa.json";
}

function empresaConfigDefault(): array {
    return [
        "nombre_comercial" => "Dorada Motors",
        "razon_social" => "ADN Import's",
        "ruc" => "",
        "direccion" => "",
        "telefono" => "",
        "correo" => "",
        "moneda" => "S/",
        "igv" => 18,
        "costo_delivery" => 0,
        "logo" => "logo_adn_imports.png",
    ];
}

function cargarConfigEmpresa(): array {
    $default = empresaConfigDefault();
    $ruta = empresaConfigRuta();

    if (!is_file($ruta)) return $default;

    $raw = file_get_contents($ruta);
    if ($raw === false || trim($raw) === "") return $default;

    $data = json_decode($raw, true);
    if (!is_array($data)) return $default;

    return array_merge($default, array_intersect_key($data, $default));
}

function guardarConfigEmpresa(array $input): array {
    $actual = cargarConfigEmpresa();

    $nuevo = [
        "nombre_comercial" => trim((string)($input["nombre_comercial"] ?? $actual["nombre_comercial"])),
        "razon_social" => trim((string)($input["razon_social"] ?? $actual["razon_social"])),
        "ruc" => preg_replace('/[^0-9]/', '', (string)($input["ruc"] ?? $actual["ruc"])),
        "direccion" => trim((string)($input["direccion_empresa"] ?? $actual["direccion"])),
        "telefono" => trim((string)($input["telefono_empresa"] ?? $actual["telefono"])),
        "correo" => strtolower(trim((string)($input["correo_empresa"] ?? $actual["correo"]))),
        "moneda" => trim((string)($input["moneda"] ?? $actual["moneda"])),
        "igv" => (float)($input["igv"] ?? $actual["igv"]),
        "costo_delivery" => max(0, (float)($input["costo_delivery"] ?? $actual["costo_delivery"])),
        "logo" => $actual["logo"],
    ];

    if ($nuevo["nombre_comercial"] === "" || $nuevo["razon_social"] === "") {
        throw new RuntimeException("Nombre comercial y razón social son obligatorios.");
    }

    if ($nuevo["correo"] !== "" && !filter_var($nuevo["correo"], FILTER_VALIDATE_EMAIL)) {
        throw new RuntimeException("El correo de la empresa no es válido.");
    }

    if ($nuevo["igv"] < 0 || $nuevo["igv"] > 100) {
        throw new RuntimeException("El IGV debe estar entre 0 y 100.");
    }

    $dir = dirname(empresaConfigRuta());
    if (!is_dir($dir) && !mkdir($dir, 0775, true) && !is_dir($dir)) {
        throw new RuntimeException("No se pudo crear la carpeta de configuración.");
    }

    $json = json_encode($nuevo, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    if ($json === false || file_put_contents(empresaConfigRuta(), $json, LOCK_EX) === false) {
        throw new RuntimeException("No se pudo guardar la configuración de la empresa.");
    }

    return $nuevo;
}
