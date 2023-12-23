//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StakeTokens is ERC20{

    constructor() ERC20("Staked Tokens","STN"){
        _mint(msg.sender,1000000*10**18);
    }
}