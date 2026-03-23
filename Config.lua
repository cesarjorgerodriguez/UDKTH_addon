local _, ns = ...

---------------------------------------------------------------------------
-- Spell IDs
---------------------------------------------------------------------------
ns.DEATH_COIL_ID       = 47541       -- Espiral de la Muerte
ns.EPIDEMIC_ID         = 207317      -- Epidemia
ns.NECROTIC_COIL_ID    = 434179      -- Necrotic Coil (mejorado con Ejercito)
ns.GRAVEYARD_ID        = 458714      -- Graveyard (mejorado con Ejercito)

---------------------------------------------------------------------------
-- Buff IDs
-- FORBIDDEN_KNOWLEDGE_ID (1242223): buff presente cuando el Ejercito de los
-- Muertos esta activo con el talento Forbidden Knowledge. Es el unico buff
-- necesario: controla tanto la deteccion de Army como el umbral FK.
---------------------------------------------------------------------------
ns.FORBIDDEN_KNOWLEDGE_ID    = 1242223  -- Forbidden Knowledge / Army of the Dead

---------------------------------------------------------------------------
-- Hero talent detection
---------------------------------------------------------------------------
ns.RIDER_CHECK_ID   = 444929   -- A Feast of Souls (Rider of the Apocalypse)
ns.SANLAYN_CHECK_ID = 434153   -- Gift of the San'layn (San'layn)

---------------------------------------------------------------------------
-- Runtime constants (not saved)
---------------------------------------------------------------------------
ns.UPDATE_INTERVAL = 0.15      -- Segundos entre actualizaciones
ns.ICON_SIZE       = 64        -- Tamaño inicial del frame (antes de ADDON_LOADED)
ns.ICON_ALPHA      = 1.0       -- Alpha inicial del frame (antes de ADDON_LOADED)

---------------------------------------------------------------------------
-- Defaults (merged into AoeDKDB on ADDON_LOADED)
-- Claves deben coincidir exactamente con los campos de AoeDKDB.
---------------------------------------------------------------------------
ns.defaults = {
    iconSize            = 64,
    iconAlpha           = 1.0,
    borderSize          = 2,    -- Grosor del borde del marco (1-8)
    epidemicThreshold   = 3,    -- Base: sin Forbidden Knowledge
    epidemicThresholdFK = 6,    -- Con Forbidden Knowledge activo
    detectionMode       = "real",
    showText            = true,
}
