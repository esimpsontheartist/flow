import Fraction from "../../contracts/Fraction.cdc"

transaction(
    vaultId: UInt256, 
    name: String,
    thumbnail: String,
    description: String,
    source: String,
    media: String,
    contentType: String,
    protocol: String
) {

    let administrator: &Fraction.Administrator
    prepare(signer: AuthAccount) {
        //get admin cpaability
        self.administrator = signer.borrow<&Fraction.Administrator>(from: Fraction.AdministratorStoragePath) 
        ?? panic("could not borrow an admin reference from this account")
    }

    execute {

        let fractionData = Fraction.FractionData(
            vaultId: vaultId,
            name: name,
            thumbnail: thumbnail,
            description: description,
            source: source,
            media: media,
            contentType: contentType,
            protocol: protocol
        )
        
        self.administrator.setVaultFractionData(vaultId: vaultId, fractionData: fractionData)
    }

}