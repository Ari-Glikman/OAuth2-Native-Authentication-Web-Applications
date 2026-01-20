Class Bank.Seed Extends %RegisteredObject
{

ClassMethod Ensure() As %Status
{
    &sql(SELECT COUNT(*) INTO :cnt1 FROM BankAccount WHERE AccountId='ACCT-1')
    If SQLCODE'=0 Quit $$$ERROR($$$GeneralError, "Seed SELECT ACCT-1 failed, SQLCODE="_SQLCODE)
    If cnt1=0 {
        &sql(INSERT INTO BankAccount(AccountId,Balance) VALUES ('ACCT-1',5))
        If SQLCODE'=0 Quit $$$ERROR($$$GeneralError, "Seed INSERT ACCT-1 failed, SQLCODE="_SQLCODE)
    }

    &sql(SELECT COUNT(*) INTO :cnt2 FROM BankAccount WHERE AccountId='ACCT-2')
    If SQLCODE'=0 Quit $$$ERROR($$$GeneralError, "Seed SELECT ACCT-2 failed, SQLCODE="_SQLCODE)
    If cnt2=0 {
        &sql(INSERT INTO BankAccount(AccountId,Balance) VALUES ('ACCT-2',0))
        If SQLCODE'=0 Quit $$$ERROR($$$GeneralError, "Seed INSERT ACCT-2 failed, SQLCODE="_SQLCODE)
    }

    Quit $$$OK
}

}
