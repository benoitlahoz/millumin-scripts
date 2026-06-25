const params = [
    { name: "Text Layer Name", defaultValue: "Layer 0" },
]

Parameter.createParameter(params[0].name, params[0].defaultValue)

function onMilluminEvent(event)
{
     if( event["name"] == "launchedColumn" )
    {
        // Ensure text is reset when launching a column via the button, otherwise the text will not be updated if the same column is launched again
        Millumin.setLayerMediaText(Parameter.get(params[0].name), "")

        setTimeout(function () 
        {
            Millumin.setLayerMediaText(Parameter.get(params[0].name), Millumin.getLaunchedColumnIndex())
        }, 25)
        
    }
}