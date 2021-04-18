using DataKnots
using CSV

employee_csv = """
    name,department,position,salary,rate
    "ANTHONY A","POLICE","POLICE OFFICER",72510,
    "DANIEL A","FIRE","FIRE FIGHTER-EMT",95484,
    "JAMES A","FIRE","FIRE ENGINEER-EMT",103350,
    "JEFFERY A","POLICE","SERGEANT",101442,
    "NANCY A","POLICE","POLICE OFFICER",80016,
    "ROBERT K","FIRE","FIRE FIGHTER-EMT",103272,
    "ALBA M","POLICE","POLICE CADET",,9.46
    "LAKENYA A","OEMC","CROSSING GUARD",,17.68
    "DORIS A","OEMC","CROSSING GUARD",,19.38
    "BRENDA B","OEMC","TRAFFIC CONTROL AIDE",64392,
    """ |> IOBuffer |> CSV.File

overtime_csv = """
    employee,month,amount
    "DANIEL A","2018-02",108
    "JAMES A","2018-01",8776
    "JAMES A","2018-03",351
    "JAMES A","2018-04",10532
    "JAMES A","2018-05",351
    "JAMES A","2018-06",8776
    "JAMES A","2018-07",10532
    "JEFFERY A","2018-05",1319
    "NANCY A","2018-01",173
    "NANCY A","2018-02",461
    "NANCY A","2018-03",461
    "NANCY A","2018-04",1056
    "NANCY A","2018-05",1933
    "ROBERT K","2018-05",1754
    """ |> IOBuffer |> CSV.File

chicago = let
    source = DataKnot(:employee => employee_csv,
                      :overtime => overtime_csv)
    @query source {
       department => begin
         employee.keep(name)
         join(begin
           overtime
           filter(employee==name)
           collect(employee=>nothing)
         end)
         group(name => department)
         collect(begin
           employee
           collect(department=>nothing)
         end)
       end}
end
