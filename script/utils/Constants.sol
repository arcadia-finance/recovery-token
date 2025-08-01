/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.30;

library Arcadia {
    address internal constant RECOVERY_CONTROLLER = 0x3889255C5a9A55137DfdF870a0C30A285978176A;
    address internal constant RECOVERY_TOKEN = 0x9089397444EF32F1777d2A9d0c0886592C8eF449;
}

library Assets {
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
}

library Deployers {
    address constant ARCADIA = 0x0f518becFC14125F23b8422849f6393D59627ddB;
}

library Safes {
    address internal constant OWNER = 0xb4d72B1c91e640e4ED7d7397F3244De4D8ACc50B;
}
