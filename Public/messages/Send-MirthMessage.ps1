function Send-MirthMessage { 
    BEGIN { 
        Write-Debug "Send-MirthMessage Beginning"
    }
    PROCESS { 
        # POST /channels/{channelId}/messages
        #
        #  body, body string - raw message data to process
        #  destinationMetaDataId, query parameter, array of integer, destinations to send msg to
        #  sourceMapEntry, query parameter, array of string, key=value pairs injected into sourceMap
        #  overwrite, query parameter, boolean, if true and original message id given, this message will overwrite existing
        #  imported, query parameter, boolean, if true marks this messag as imported, if overwriting statistics not decremented
        #  originalMessageId, query parameter, long, the original message id this msg is associated with


    }
    END { 
        Write-Debug "Send-MirthMessage Ending"
    }
}  #  Send-MirthMessage [UNDER CONSTRUCTION]