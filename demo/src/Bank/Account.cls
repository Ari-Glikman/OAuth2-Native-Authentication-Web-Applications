Class Bank.Account Extends %Persistent [ SqlTableName = BankAccount ]
{

Property AccountId As %String(MAXLEN = 50) [ Required ];

Property Balance As %Integer [ InitialExpression = 0 ];

Index AccountIdIdx On AccountId [ Unique ];

}
