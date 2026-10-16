/// Makes a typed value safe to put in a request address (?Name=value).
///
/// Letters, digits and - _ . ~ stay exactly as they are, so normal values
/// give the same address as before. Characters with a meaning in addresses
/// are encoded so the server receives what was typed: without this,
/// "Ab+12" arrived as "Ab 12", "M&S" as "M", "R#12" as "R".
String q(Object? value) => Uri.encodeQueryComponent('$value');
