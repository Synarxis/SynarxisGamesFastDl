#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;

init()
{
    if (!isDefined(level.custom_zone_names))
        level.custom_zone_names = [];

    level.custom_zone_names["culdesac_yellow_zone"] = "Yellow House Cul-de-sac";
    level.custom_zone_names["culdesac_green_zone"] = "Green House Cul-de-sac";
    level.custom_zone_names["truck_zone"] = "Truck";
    level.custom_zone_names["openhouse1_f1_zone"] = "Green House Downstairs";
    level.custom_zone_names["openhouse1_f2_zone"] = "Green House Upstairs";
    level.custom_zone_names["openhouse1_backyard_zone"] = "Green House Backyard";
    level.custom_zone_names["openhouse2_f1_zone"] = "Yellow House Downstairs";
    level.custom_zone_names["openhouse2_f2_zone"] = "Yellow House Upstairs";
    level.custom_zone_names["openhouse2_backyard_zone"] = "Yellow House Backyard";
    level.custom_zone_names["ammo_door_zone"] = "Yellow House Backyard Door";
}
