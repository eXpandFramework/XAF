﻿using System.Collections.Generic;
using System.Linq;
using DevExpress.ExpressApp.Model.Core;
using Fasterflect;
using Xpand.Source.Extensions.System.Refelction;
using Xpand.Source.Extensions.XAF.Model;

namespace Xpand.XAF.Modules.ModelMapper{
    public static class ModelMapperBinderService{
        public static void BindTo(this IModelModelMap modelModelMap, object instance){
            ((IModelNodeEnabled) modelModelMap).BindTo( instance);
        }

        private static void BindTo(this IModelNodeEnabled modelNodeEnabled, object instance){
            if (modelNodeEnabled.NodeEnabled){
                var modelNode = ((ModelNode) modelNodeEnabled);
                var modelNodeInfo = modelNode.NodeInfo;
                var propertyInfos = instance.GetType().Properties();
                var propertiesHashSet = new HashSet<string>(propertyInfos.Select(info => info.Name));
                var modelValueInfos = modelNodeInfo.ValuesInfo.Where(info => IsValidInfo(info, propertiesHashSet)).ToArray();
                foreach (var valueInfo in modelValueInfos){
                    var propertyType = valueInfo.PropertyType == typeof(string)
                        ? valueInfo.PropertyType
                        : valueInfo.PropertyType.GetGenericArguments().First();
                    var value = modelNodeEnabled.GetValue(valueInfo.Name, propertyType);
                    if (value != null) instance.TrySetPropertyValue(valueInfo.Name, value);
                }

                for (int i = 0; i < modelNodeEnabled.NodeCount; i++){
                    if (modelNodeEnabled.GetNode(i) is IModelNodeEnabled nodeEnabled){
                        var propertyValue = instance.GetPropertyValue(nodeEnabled.Id());
                        if (propertyValue != null) (nodeEnabled).BindTo(propertyValue);
                    }
                }
            }
        }

        private static bool IsValidInfo(ModelValueInfo info, HashSet<string> properties){
            return !info.IsReadOnly && (info.PropertyType.IsNullableType() || info.PropertyType == typeof(string)) && properties.Contains(info.Name);
        }
    }
}