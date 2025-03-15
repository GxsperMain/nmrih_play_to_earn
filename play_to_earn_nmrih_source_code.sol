// SPDX-License-Identifier: FTM
pragma solidity 0.8.26;
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/refs/heads/master/contracts/token/ERC721/ERC721.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/refs/heads/master/contracts/access/Ownable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/refs/heads/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "https://raw.githubusercontent.com/GxsperMain/play_to_earn/refs/heads/main/PlayToEarn.sol";

contract PlayToEarnNMRIH is ERC721URIStorage, Ownable {
    PlayToEarnCoin private _playToEarn =
        PlayToEarnCoin(address(0xb88643dA0Bf6d5D7aB15B2Ec074dB38f6285F72A));

    uint256[] public availableTokens = [1];
    uint256[] public rarityCostIndex = [20000000000000000000];
    uint16[] public rarityChanceIndex = [100];
    uint256 public maxRarityIndex = 0;

    uint256 public nextTokenId; // NFT Token ID

    constructor()
        ERC721("Play To Earn NMRIH", "PTENMRIH")
        Ownable(address(0x2c9f3404c42d555c5b766b1f59d6FF24D27f2ecE))
    {}

    function getAllowance() external view returns (uint256) {
        return _playToEarn.allowance(msg.sender, address(this));
    }

    function mintNFT(uint256 rarity) external payable returns (uint256) {
        // Check rarity
        require(rarity <= maxRarityIndex, "Invalid rarity number");

        // Getting the nft cost
        uint256 cost = rarityCostIndex[rarity];

        // Allowance check
        uint256 userAllowance = _playToEarn.allowance(
            msg.sender,
            address(this)
        );
        require(
            userAllowance >= cost,
            string(
                abi.encodePacked(
                    "Insufficient allowance, you must approve: ",
                    Strings.toString(cost),
                    ", to ",
                    Strings.toHexString(uint160(address(this)), 20)
                )
            )
        );

        // Check user balance
        uint256 userBalance = _playToEarn.balanceOf(address(msg.sender));
        require(userBalance >= cost, "Not enough Play To Earn");

        // Transfer to the contract
        _playToEarn.transferFrom(msg.sender, address(this), cost);

        // Burning the received coins
        _playToEarn.burnCoin(cost);

        uint256 tokenId = generateNFT(msg.sender, rarityChanceIndex[rarity]);
        nextTokenId++;
        return tokenId;
    }

    function generateNFT(address receiverAddress, uint16 rollChance)
        internal
        returns (uint256)
    {
        // Generate rarity
        uint256 rarity = 0;
        for (uint256 i = 0; i < 10; i++) {
            uint256 chance = getRandomNumber(1000);
            if (chance <= rollChance) {
                rarity++;
            }
        }
        // Generate the skin id
        uint256 skinId = getRandomNumber(availableTokens[rarity]);

        // Generate token data
        string memory metadataURI = string(
            abi.encodePacked(
                Strings.toString(rarity),
                "-",
                Strings.toString(skinId)
            )
        );

        // Generating token
        _safeMint(receiverAddress, nextTokenId);
        _setTokenURI(nextTokenId, metadataURI);
        return nextTokenId;
    }

    function burnNFT(uint256 tokenId) public {
        require(
            ownerOf(tokenId) == msg.sender,
            "You can only burn your own NFTs"
        );
        _burn(tokenId);
    }

    function getRandomNumber(uint256 max) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        msg.sender,
                        block.prevrandao
                    )
                )
            ) % max;
    }

    function increaseTokenCount(uint8 rarity) external onlyOwner {
        require(rarity <= maxRarityIndex, "Invalid rarity number");
        availableTokens[rarity]++;
    }

    function increaseRarityCount(uint256 rarityCost, uint16 rarityChance)
        external
        onlyOwner
    {
        availableTokens.push(1);
        rarityCostIndex.push(rarityCost);
        rarityChanceIndex.push(rarityChance);
        maxRarityIndex++;
    }
}
