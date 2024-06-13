# How gas is saved?

During mint operation, there is a possibility to do a batch mint. ERC721A doesnt write to storage on each tokenId during batch mint, e.g. 1 -> 0xa, 2 -> 0xb, balanceOf(0xa) = 1, balanceOf(0xa) = 2. What they do is because of the nature of batch mint, therefore 1 owner have multiple sequental token Ids, they pack the data for all the tokenIds in a sequence. This way the reduce the write to storage operations which are expensive in gas cost.

# Where more gas is spend with ERC721A?
During reading the balanceOf a tokenId. Its not just simply reading from a map. Due to the packed nature of storing information to save on write operations, then to deduce the owner of a tokenId ERC721A implementation have to do more reads to determine the owner.


# Use cases for wrapped NFT
 - Bridging from other chains
 - Used as collateral

# Opensea workflow
 - scans for Transfer events (off chain)
 - ERC20 and ERC721 Transfer events share the same signature(on chain)
 - Checks supportsInterface to determine if its ERC20 or ERC721 (making static call)
