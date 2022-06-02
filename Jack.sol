// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract Jack is ERC721, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    
    address private stakingAddress;


    string private baseTokenUri;
    string public baseTokenUri1;
    string public baseTokenUri2;
    string public baseTokenUri3;
    
    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => uint256) private tokenLevel;

    modifier callerIsStaking() {
        require(msg.sender == stakingAddress, "Jack :: can only be called by Staking contract");
        _;
    }

    constructor() ERC721("Jack", "Jack") {
        setTokenUri("ipfs://QmTJvHzqqRTc18C2G6TKskfjfgY2FNikZnYcc42sz7KBCd/");
    }

    function setStakingAddress(address _stakingAddress) external onlyOwner{
        stakingAddress = _stakingAddress;
    }

    function getStakingAddress() external view returns (address){
        return stakingAddress;
    }

    function updateLevel(uint256 tokenId, uint256 _level) external callerIsStaking{
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        if(tokenLevel[tokenId] <=3){
            tokenLevel[tokenId]=_level;
        }
    }

    function getTokenLevel(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return tokenLevel[tokenId];
    }

    function mint() public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenUri;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        // string memory baseURI = _baseURI();

        string memory baseURI;
        uint256 tknLvl = getTokenLevel(tokenId);

        if(tknLvl == 0){
            baseURI = _baseURI();
        }else if(tknLvl == 1){
            baseURI = baseTokenUri1;
        }else if(tknLvl == 2){
            baseURI = baseTokenUri2;
        }else if(tknLvl == 3){
            baseURI = baseTokenUri3;
        }else{
            baseURI = _baseURI();
        }

        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    function setTokenUri(string memory _baseTokenUri) public onlyOwner{
        baseTokenUri = _baseTokenUri;
    }

    function setTokenUris(
            string memory _baseTokenUri1,
            string memory _baseTokenUri2,
            string memory _baseTokenUri3
        ) public onlyOwner{
            baseTokenUri1 = _baseTokenUri1;
            baseTokenUri2 = _baseTokenUri2;
            baseTokenUri3 = _baseTokenUri3;
    }
   
}