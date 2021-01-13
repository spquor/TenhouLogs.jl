using Downloads

function printprogress(total, current)
    # print progress every 200kb downloaded
    if (total == current)
        global lastprinted = 0
    elseif (current > lastprinted + 2e5)
        global lastprinted = current
        write(stdout, "\e[1G" * "< Downloading: $current/$total\t")
    end
end

for arg in ARGS
    # read args and download all index archives for specified years
    Downloads.download("http://tenhou.net/sc/raw/scraw$arg.zip",
            "scraw$arg.zip", progress = printprogress, verbose = true)
    write(stdout, "* Download complete: scraw$arg.zip\n\n")
end
