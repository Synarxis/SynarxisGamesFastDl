#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;

init()
{
    if (!isDefined(level.custom_zone_names))
        level.custom_zone_names = [];

    level.custom_zone_names["zone_pri"] = "Bus Depot";
    level.custom_zone_names["zone_pri2"] = "Bus Depot Hallway";
    level.custom_zone_names["zone_station_ext"] = "Outside Bus Depot";
    level.custom_zone_names["zone_trans_2b"] = "Fog After Bus Depot";
    level.custom_zone_names["zone_trans_2"] = "Tunnel Entrance";
    level.custom_zone_names["zone_amb_tunnel"] = "Tunnel";
    level.custom_zone_names["zone_trans_3"] = "Tunnel Exit";
    level.custom_zone_names["zone_roadside_west"] = "Outside Diner";
    level.custom_zone_names["zone_gas"] = "Gas Station";
    level.custom_zone_names["zone_roadside_east"] = "Outside Garage";
    level.custom_zone_names["zone_trans_diner"] = "Fog Outside Diner";
    level.custom_zone_names["zone_trans_diner2"] = "Fog Outside Garage";
    level.custom_zone_names["zone_gar"] = "Garage";
    level.custom_zone_names["zone_din"] = "Diner";
    level.custom_zone_names["zone_diner_roof"] = "Diner Roof";
    level.custom_zone_names["zone_trans_4"] = "Fog After Diner";
    level.custom_zone_names["zone_amb_forest"] = "Forest";
    level.custom_zone_names["zone_trans_10"] = "Outside Church";
    level.custom_zone_names["zone_town_church"] = "Outside Church To Town";
    level.custom_zone_names["zone_trans_5"] = "Fog Before Farm";
    level.custom_zone_names["zone_far"] = "Outside Farm";
    level.custom_zone_names["zone_far_ext"] = "Farm";
    level.custom_zone_names["zone_brn"] = "Barn";
    level.custom_zone_names["zone_farm_house"] = "Farmhouse";
    level.custom_zone_names["zone_trans_6"] = "Fog After Farm";
    level.custom_zone_names["zone_amb_cornfield"] = "Cornfield";
    level.custom_zone_names["zone_cornfield_prototype"] = "Prototype";
    level.custom_zone_names["zone_trans_7"] = "Upper Fog Before Power Station";
    level.custom_zone_names["zone_trans_pow_ext1"] = "Fog Before Power Station";
    level.custom_zone_names["zone_pow"] = "Outside Power Station";
    level.custom_zone_names["zone_prr"] = "Power Station";
    level.custom_zone_names["zone_pcr"] = "Power Station Control Room";
    level.custom_zone_names["zone_pow_warehouse"] = "Warehouse";
    level.custom_zone_names["zone_trans_8"] = "Fog After Power Station";
    level.custom_zone_names["zone_amb_power2town"] = "Cabin";
    level.custom_zone_names["zone_trans_9"] = "Fog Before Town";
    level.custom_zone_names["zone_town_north"] = "North Town";
    level.custom_zone_names["zone_tow"] = "Center Town";
    level.custom_zone_names["zone_town_east"] = "East Town";
    level.custom_zone_names["zone_town_west"] = "West Town";
    level.custom_zone_names["zone_town_south"] = "South Town";
    level.custom_zone_names["zone_bar"] = "Bar";
    level.custom_zone_names["zone_town_barber"] = "Bookstore";
    level.custom_zone_names["zone_ban"] = "Bank";
    level.custom_zone_names["zone_ban_vault"] = "Bank Vault";
    level.custom_zone_names["zone_tbu"] = "Below Bank";
    level.custom_zone_names["zone_trans_11"] = "Fog After Town";
    level.custom_zone_names["zone_amb_bridge"] = "Bridge";
    level.custom_zone_names["zone_trans_1"] = "Fog Before Bus Depot";
}
