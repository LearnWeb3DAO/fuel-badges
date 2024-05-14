library;

pub enum MintError {
    CannotMintMoreThanOneNFTWithSubId: (),
    NFTAlreadyMinted: (),
}

pub enum UnexpectedError {
    NotAllowed: (),
}

pub enum SetError {
    ValueAlreadySet: (),
}
