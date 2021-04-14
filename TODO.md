
TODO STRING PERFORMANCE IMPROVEMENTS
1. searching string inside string is very slow
2. immutable strings could be changed to cstrings with indexing
3. hash function for dicts could be optimized maybe?


Maybe string views?
```
using StringViews

macro sview(sss, n1, n2)
    return quote
        StringView(@view $(esc(sss)).data[$(esc(n1)):$(esc(n2))])
    end
end
```
