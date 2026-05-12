/*
 * SPDX-License-Identifier: GPL-2.0
 * Copyright (c) 2026 Intel Corporation.
 */

External (_SB.PC00.IPU0, DeviceObj) // Reuse IPU0 Device from existing SSDT ACPI table

Scope (\_SB.PC00.IPU0)
{
    Name (_DSD, Package () // _DSD: Device Specific Data
    {
        ToUUID("dbb8e3e6-5886-4ba6-8795-1319f52a966b"), // Hierarchical Data Extension
        Package () {
            /*
             * mipi-img-port are MIPI ports, that can be connected to Camera (Deserializer or MIPI direct Camera) 
             * mipi-disco-img.c will use these information to create fwnode.
             */
            Package () { "mipi-img-port-0", "PRT0" }, // MIPI Port 0 of SOC
            Package () { "mipi-img-port-1", "PRT1" }, // MIPI Port 1 of SOC
            Package () { "mipi-img-port-2", "PRT2" }, // MIPI Port 2 of SOC
            Package () { "mipi-img-port-3", "PRT3" }, // MIPI Port 3 of SOC
        },
    })
    Name (PRT0, Package()
    {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
        Package () { 
            Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4 } }
        },
    })
    Name (PRT1, Package()
    {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
        Package () { 
            Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4 } }
        },
    })
    Name (PRT2, Package()
    {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
        Package () { 
            Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4 } }
        },
    })
    Name (PRT3, Package()
    {
        ToUUID("daffd814-6eba-4d8c-8a91-bc9bbf4aa301"), // Device Properties
        Package () { 
            Package () { "mipi-img-data-lanes", Package () { 1, 2, 3, 4 } }
        },
    })
}
