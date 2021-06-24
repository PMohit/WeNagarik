// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Government.sol";

 

contract Token is ERC777, Ownable {
    
    Government private _government;

   
    constructor(
        address owner_,
        uint256 initialSupply,
        address appAddress,
        address[] memory defaultOperators
    ) public ERC777("CITIZEN", "CTZ", defaultOperators) {
        _government = Government(appAddress);
        transferOwnership(owner_);
        _mint(owner(), initialSupply, "", "");
        _government.setToken();
    }

     
    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount, "", "");
    }
}
