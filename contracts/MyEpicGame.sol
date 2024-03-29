// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Helper we wrote to encode in Base64
import "./libraries/Base64.sol";

// NFT contract to inherit from 
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

//Helper functions OpenZeppelin provides
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "hardhat/console.sol";

// Our contract inherits from ERC721, which is the standard NFT contract
contract MyEpicGame is ERC721 {

    struct CharacterAttributes {
        uint characterIndex;
        string name;
        string imageURI;
        uint hp;
        uint maxHp;
        uint attackDamage;
    }

    // The tokenId is the NFT unique identifier, which is just a number that goes
    //1,2,3 e.t.c
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Little array to hold the default data for our characters
    CharacterAttributes[] defaultCharacters;

    // create a mapping from the NFT's tokenId => that NFTs attributes.
    mapping(uint256 => CharacterAttributes) public nftHolderAttributes;

    struct BigBoss {
        string name;
        string imageURI;
        uint hp;
        uint maxHp;
        uint attackDamage;
    }

    BigBoss public bigBoss;

    // mapping from an address => the NFT tokedId. Gives me an easy way to 
    //store the owner of the NFT and reference it later
    mapping(address => uint256) public nftHolders;

    event CharacterNFTMinted(address sender, uint256 tokenId, uint256 characterIndex);
    event AttackComplete(uint newBossHp, uint newPlayerHp);

    constructor(
        string[] memory characterNames,
        string[] memory characterImageURIs,
        uint[] memory characterHp,
        uint[] memory characterAttackDmg,
        string memory bossName,
        string memory bossImageURI,
        uint bossHp,
        uint bossAttackDamage
    )
        ERC721("Heroes", "HERO") 
    {
        //Initialize the boss. Save it to our global "bigBoss" state variable
        bigBoss = BigBoss({
            name: bossName,
            imageURI: bossImageURI,
            hp: bossHp,
            maxHp: bossHp,
            attackDamage: bossAttackDamage
        });

        console.log("Done initializing boss %s w/ HP %s, img %s", bigBoss.name, bigBoss.hp, bigBoss.imageURI);


        // Loop through all the characters, and save their values in our contract 
        //so we can use them later when we mint our NFTs.
        for (uint256 i = 0; i < characterNames.length; i += 1) {
            defaultCharacters.push(CharacterAttributes({
                characterIndex: i,
                name: characterNames[i],
                imageURI: characterImageURIs[i],
                hp: characterHp[i],
                maxHp: characterHp[i],
                attackDamage: characterAttackDmg[i]
            }));

            CharacterAttributes memory c = defaultCharacters[i];
            console.log("Done initializing %s w/ HP %s, img %s", c.name, c.hp, c.imageURI);
        }

        // increment tokenIds here so that my first NFT has an ID of 1.
        _tokenIds.increment();
   }

   // Users will be able to hit this function and get their NFT based on the
   //characters they send in!
   function mintCharacterNFT(uint _characterIndex) external {
       // Get the current tokenId 
       uint256 newItemId = _tokenIds.current();

       // The magical function! Assigns the tokenId to the caller's wallet address
        _safeMint(msg.sender, newItemId);

       // We map the tokenId => their character attributes.
       nftHolderAttributes[newItemId] = CharacterAttributes({
           characterIndex: _characterIndex,
           name: defaultCharacters[_characterIndex].name,
           imageURI: defaultCharacters[_characterIndex].imageURI,
           hp: defaultCharacters[_characterIndex].hp,
           maxHp: defaultCharacters[_characterIndex].hp,
           attackDamage: defaultCharacters[_characterIndex].attackDamage
       });

       console.log("Minted NFT w/ tokenId %s and characterIndex %s", newItemId, _characterIndex);

       // keep an easy way to see who owns what NFT
       nftHolders[msg.sender] = newItemId;

       // Increment the tokenId for the next person that uses it
       _tokenIds.increment();


       emit CharacterNFTMinted(msg.sender, newItemId, _characterIndex);
   }


   function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        CharacterAttributes memory charAttributes = nftHolderAttributes[_tokenId];

        string memory strHp = Strings.toString(charAttributes.hp);
        string memory strMaxHp = Strings.toString(charAttributes.maxHp);
        string memory strAttackDamage = Strings.toString(charAttributes.attackDamage);

        string memory json = Base64.encode(
            bytes(
                string(
                abi.encodePacked(
          '{"name": "',
          charAttributes.name,
          ' -- NFT #: ',
          Strings.toString(_tokenId),
          '", "description": "This is an NFT that lets people play in the game Metaverse Slayer!", "image": "',
          charAttributes.imageURI,
          '", "attributes": [ { "trait_type": "Health Points", "value": ',strHp,', "max_value":',strMaxHp,'}, { "trait_type": "Attack Damage", "value": ',
          strAttackDamage,'} ]}'
        )
      )
    )
  );

  string memory output = string(
    abi.encodePacked("data:application/json;base64,", json)
  );
  
  return output;
}


    function attackBoss() public {
        // Get the state of the player's NFT.
        uint256 nftTokenIdOfPlayer = nftHolders[msg.sender];
        CharacterAttributes storage player = nftHolderAttributes[nftTokenIdOfPlayer];
        console.log("\nPlayer w/ character %s about to attack. Has %s HP and %s AD", player.name, player.hp, player.attackDamage);
        console.log("Boss %s has %s HP and %s AD", bigBoss.name, bigBoss.hp, bigBoss.attackDamage);
        // Make sure that the player has more that 0 hp.
        require (
            player.hp > 0,
            "Error: character must have HP to attack the boss."
        );
        // Make sure that the boss has more than 0 hp
        require (
            bigBoss.hp > 0,
            "Error: boss must have HP to attack boss."
        );
        // Allow the player to attack the boss. 
        if (bigBoss.hp < player.attackDamage) {
            bigBoss.hp = 0;
        } else {
            bigBoss.hp = bigBoss.hp - player.attackDamage;
        }
        // Allow the boss to attack the player.
        if (player.hp < bigBoss.attackDamage) {
            player.hp = 0;
        } else {
            player.hp = player.hp - bigBoss.attackDamage;
        }

        // Console it for ease
        console.log("Player attacked boss. New boss hp: %s", bigBoss.hp);
        console.log("Boss attacked player. New player hp: %s\n", player.hp);
    
        emit AttackComplete(bigBoss.hp, player.hp);
    }

    function checkIfUserHasNFT() public view returns (CharacterAttributes memory) {
        // get the tokenId of the user's character NFT
        uint256 userNftTokenId = nftHolders[msg.sender];
        // If the user has a tokenId in the map their character.
        if (userNftTokenId > 0) {
            return nftHolderAttributes[userNftTokenId];
        }
        // Else, return empty character
        else {
            CharacterAttributes memory emptyStruct;
            return emptyStruct;
        }
    }

    function getAllDefaultCharacters() public view returns (CharacterAttributes[] memory) {
        return defaultCharacters;
    }

    function getBigBoss() public view returns (BigBoss memory) {
        return bigBoss;
    }
}